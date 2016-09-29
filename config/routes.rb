# Encoding: utf-8

Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
  devise_for :users,
             path_names: { sign_in: 'login',
                           sign_out: 'logout',
                           sign_up: 'register' },
             controllers: { sessions: 'users/sessions',
                            passwords: 'users/passwords',
                            registrations: 'users/registrations',
                            unlocks: 'users/unlocks' }

  get 'users/invitation' => 'users/user_invitations#show', as: :new_user_invitation
  post 'users/invitation/accept' => 'users/user_invitations#accept', as: :accept_user_invitation
  resources :users, only: [:index, :show, :edit, :update] do
    get 'accounts' => 'users#accounts'
    get 'user_invitations' => 'users#user_invitations'
  end
  namespace :admin do
    resources :accounts, except: [:destroy] do
      resources :invoices, only: [:index]
      resources :user_invitations
      get 'cancel' => 'accounts#confirm_cancel'
      patch 'cancel' => 'accounts#cancel'
      get 'events' => 'accounts#events'
      get 'restore' => 'accounts#confirm_restore'
      patch 'restore' => 'accounts#restore'
      get 'users' => 'accounts#users'
    end
    resources :cancellation_categories, except: [:destroy] do
      resources :cancellation_reasons, except: [:destroy]
    end
    resources :invoices, only: [:index, :show]
    resources :plans do
      get 'accounts' => 'plans#accounts'
    end
    resources :users do
      get 'accounts' => 'users#accounts'
      get 'user_invitations' => 'users#user_invitations'
    end
    get 'events' => 'dashboard#events'
    get 'jobs' => 'dashboard#jobs'
    get 'user_invitations' => 'user_invitations#index'
    root to: 'dashboard#index'
  end

  get 'pricing' => 'marketing#pricing'
  get 'signup/:plan_id' => 'marketing#signup', as: :signup
  post 'signup' => 'marketing#register', as: :register

  scope ':path' do
    namespace :settings do
      resource :account, only: [:show, :edit, :update]
      resource :card, only: [:show, :edit, :update]
      resources :invoices, only: [:index, :show]
      resource :plan, only: [:show, :update, :destroy] do
        get 'cancel'
        patch 'pause'
        get ':id' => 'plans#edit', as: :edit
      end
      resources :user_permissions, except: [:create, :new]
      resources :user_invitations
      root to: 'dashboard#index'
    end
    root to: 'dashboard#index', as: :tenant_root
  end

  root to: 'marketing#index'
end
