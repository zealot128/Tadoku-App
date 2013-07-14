class Bot < ActiveRecord::Base
include Calc,Tweet, ApplicationHelper

MEDREGEX = /#(books?|manga|net|fullgame|fgame|game|news|subs|sentences?|nico|undo|lyric|reg|target)/i
LANGREGEX = /#(fr|de|es|en|ko|th |zh|it|nl|pl|el|ru|eo|sv|he|nn|nb|la|hu|jp|fi|af|ar|be|pt|hr)/i

	#this got nasty real quick. Now I remember why I seperated the register and the bot
	def self.main 
		client = Twitter::Client.new
		since = get_id
		puts since
		updates = client.mentions(:since_id=> since)
		updates.reverse!
		updates.each do |update|
			relevance = update.text.scan(MEDREGEX)
			if !relevance.empty?
					partaker = update.user.screen_name
					reg_check = update.text.scan(/#reg/i)
				if !reg_check.empty?
					if regis_check(update) == false

						 regis(update,client)
					elsif regis_check(update).nil?
						puts "Creating new User"
						if update.user.time_zone.nil?
							Tweet::no_tz(update.user.screen_name)
						else
							new_user = User.new(uid: update.user.id, name: update.user.screen_name, provider: "twitter", time_zone: update.user.time_zone)
							new_user.save
							bn_usr = User.find_by_uid(update.user.id)
							over_round = bn_usr.rounds.new(:round_id => 1, :pcount => 0)
							over_round.save
							regis(update,client)
						end
					else
						Tweet::already_regis(partaker,client)
					end
				elsif !regis_check(update)  #Check tweeter's registration status if they are not attempting to register
					Tweet::not_regis(partaker,client)
				elsif !update.text.scan(/#target/i).empty?
					goal_change(update,client)
				else
					split_up = update.text.split(/;/)
					split_up.each do |reup|
						rel_check = reup.scan(MEDREGEX)
						if !rel_check.empty?
							processor(update,reup,client)
						end
					end
					upuser = User.find_by_uid(update.user.id)
					new_total = upuser.rounds.find_by_round_id(ApplicationHelper::curr_round).pcount
					rank = Round::rank(upuser,ApplicationHelper::curr_round)
					Tweet::tweet_up(upuser,new_total.round(2),rank,client)
				end
			end
			since = update.id
			save_id(since)
		end
	end	


	def self.processor(request,subreq,client)
		usr = User.find_by_uid(request.user.id)
		usr_time = Time.now.in_time_zone("#{usr.time_zone}")
		start_time = UpdatesHelper::start_date_full(ApplicationHelper::curr_round.to_s)
		end_time = UpdatesHelper::end_date_full(ApplicationHelper::curr_round.to_s)
		if usr_time.to_date < start_time.to_date
			Tweet::early_warn(request.user.screen_name)
		elsif usr_time.to_date > end_time.to_date
			Tweet::late_submit(request.user.screen_name)			
		else
			unless !subreq.scan(/#undo/i).empty? #this is what happens when you tack on an important fucntion last.
				medium = subreq.scan(MEDREGEX).first.to_s.gsub(/[^A-Za-z]/, '')
				language = subreq.scan(LANGREGEX).first.to_s.to_s.gsub(/[^A-Za-z]/, '')
				sub_read = subreq.scan(/[.]?\d+/).first.to_f

				if medium == "sentences" || medium == "sentence"
					medium = "sent"
				end

				medium = "book" if medium =="books"

				medium = "fgame" if medium == "fullgame"

				if language.empty? 
					usr = User.find_by_uid(request.user.id)
					language = usr.rounds.find_by_round_id(ApplicationHelper::curr_round).lang1
				end
				
				usrlng = lang_check(request,language)
				
				if usrlng == true

					new_read = Calc::score_calc(sub_read,medium,language).to_f

					# really wanted to make this a one liner but I need to pass the variable just in case
					if !subreq.scan(/#dr/).empty?
						new_read = Calc::dr(new_read)
						sub_Read = Calc::dr(sub_read)
						dr = true
					else
						dr = false
					end

					if !subreq.scan(/#(second|third|fourth|fifth)/i).empty?
						reps = repinterp(subreq) 
						new_read = Calc::repeat(new_read,reps)
						sub_read = Calc::repeat(sub_read,reps)
					else
						reps = 0
					end
					db_update(request,new_read,medium,language,dr,reps,sub_read,client)
				else
					user = request.user.screen_name
					Tweet::not_regis_lang(user,language,client)
				end
			else
				undo(request,ApplicationHelper::curr_round,client)
			end
		end
	end

	def self.regis(request, client)
		puts "User registering"
		requester = request.user.screen_name
		binding.pry
		goal = request.text.to_s.scan(/[.]?\d+/)
		user = User.find_by_uid(request.user.id)
		user_total = user.rounds.find_by_round_id(1).pcount.to_f
		usr_tier = Tier::tier(user_total)
		new_round = user.rounds.new(round_id: ApplicationHelper::curr_round, goal: goal.first, tier: usr_tier)
		new_round.save


		chopped_lang = request.text.split(/;/)
		sep_lang = chopped_lang.scan(LANGREGEX)
		x = 0

		if sep_lang.count == 1
				puts "no register langauge"
				regis_lang = "jp"
				usr_round = user.rounds.find_by_round_id(ApplicationHelper::curr_round).update_attributes(:lang1 => regis_lang)
				usr_round = user.rounds.find_by_round_id(ApplicationHelper::curr_round)
				Tweet::regis_tweet(user, usr_round,client)
		else

			sep_lang.each do |lang|
				puts "seplang start"
				regis_lang = lang.scan(LANGREGEX)

				#adding legacy "default" jp language function
				#this is sort of nasty
				
					#this is DEFINITELY odd 
				regis_lang = regis_lang.to_s.gsub(/[^A-Za-z0-9_]+/,'')
				if x == 0  
					puts "one language"
					user.rounds.find_by_round_id(ApplicationHelper::curr_round).update_attributes(:lang1 => regis_lang) #had the idea to make this one loop and just starting x at 1 and writing lang#{x} in the update attributes field
					x += 1
				elsif x == 1
					puts "two language"
					user.rounds.find_by_round_id(ApplicationHelper::curr_round).update_attributes(:lang2 => regis_lang)
					x += 1
				elsif x == 2
					puts "three language"
					user.rounds.find_by_round_id(ApplicationHelper::curr_round).update_attributes(:lang3 => regis_lang)
					x += 1
				else
					Tweet::regis_exceed(requester,client)
				end
			end
			usr_round = user.rounds.find_by_round_id(ApplicationHelper::curr_round)
			puts "should be tweeting about that registration now "
			Tweet::regis_tweet(user,usr_round,client)
		end
	end

	def self.db_update(req,count,med,lang,double,rep,fresh_count,client)
		user = User.find_by_uid(req.user.id)
		total = user.rounds.find_by_round_id(ApplicationHelper::curr_round).pcount

		new_total = count.to_f + total.to_f

		usr_tme =  ApplicationHelper::convert_usr_time(user,Time.now)

		new_update = Update.new(:user_id => user.id, :raw => fresh_count ,:newread => count, :medium => med, :lang => lang, :dr => double, :repeat => rep, :round_id => ApplicationHelper::curr_round,:recpage => total, :created_at_in_user_time => usr_tme)
		new_update.save
		ApplicationHelper::medium_update(user,ApplicationHelper::curr_round,med,fresh_count,new_total)
	end

	def self.repinterp(txt)
		if !txt.scan(/#second/).empty?
			repeat_count = 1
		elsif !txt.scan(/#third/).empty?
			repeat_count = 2
		elsif !txt.scan(/#fourth/).empty?
			repeat_count = 3
		else
			repeat_count = 4 #kind of lazy but accounts for unforseen repeat call numbers, could potential be a problem. re-evaluate later
		end	
	end

	def self.regis_check(request)
		user = User.find_by_uid(request.user.id)
		if user == nil
			return nil
		else
			round_check = user.rounds.find_by_round_id(ApplicationHelper::curr_round)
			if round_check.nil?
				return false
			else
				return true
			end
		end
	end

	def self.get_id
		status = File.read("/home/ec2-user/tadoku-app/lib/since_id.txt")
		return status
	end

	def self.save_id(since_id)
		status_file = File.new("/home/ec2-user/tadoku-app/lib/since_id.txt","w")
		status_file.write(since_id)
		status_file.close
	end	

	def self.undo(request,round,client)
		requester_id = request.user.id
		user = User.find_by_uid(requester_id)
		old_total = ApplicationHelper::rollback(user,round)
		if old_total == false
			Tweet::no_undo(user)
		else
			rank = Round::rank(user,ApplicationHelper::curr_round)
			Tweet::undo_tweet(user, old_total.round(2),rank,client)
		end
	end

	def self.lang_check(req,lang)
		user = User.find_by_uid(req.user.id)
		round_lang = user.rounds.find_by_round_id(ApplicationHelper::curr_round)
		langarry = [round_lang.lang1, round_lang.lang2, round_lang.lang3]

		langarry.each do |userlang|
			if lang == userlang
				return true
			end
		end
		return false
	end

	def self.goal_change(request,client)
		user = User.find_by_uid(request.user.id)
		 if user.nil?
		 	Tweet.not_regis(request.user.name,client)
		 else
			new_goal =  request.text.scan(/\d+/).first.to_f
			round = user.rounds.find_by_round_id(ApplicationHelper::curr_round)
			if round.nil?
				Tweet.not_regis(request.user.name,client)
			else
				round.goal  = new_goal
				round.save
				Tweet.goal_update(user.name,new_goal,client)
			end
		end
	end
end
