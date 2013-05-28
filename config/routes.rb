TadokuApp::Application.routes.draw do
  resources :users
  resources :sessions, only: [:create, :destroy]
  resources :rounds
  resources :updates

  resources :users do
    resources :updates, :rounds
  end
  

  root to: 'view_pages#home'

  match '/manual', to: 'view_pages#manual'
  match '/about', to: 'view_pages#about'
  match '/ranking', to: 'rounds#index'
  
  match '/signin' => redirect("/auth/twitter")
  match '/signout', to: "sessions#destroy", via: :delete

  match 'rounds/:round_id/:lang', to: "rounds#lang_show"
  match 'rounds/:round_id' => 'rounds#show'
  match '/rounds/:round_id/users/:user_id' => 'users#old_show', :as => :old_user
  match '/ranking/0' => 'rounds#round0_show', :as => :zero


  match "auth/twitter/callback" => "sessions#create"
end

