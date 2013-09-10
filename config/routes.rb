# -*- encoding : utf-8 -*-
Development::Application.routes.draw do
	scope "/:locale" do
		Rails.application.eager_load!
		res = ApplicationController.descendants.map do |controller|
			controller.to_s.underscore.sub(/_controller$/, '').to_sym
		end
		resources :logins do
			collection do
				post 'destroy'
				get 'destroy'
			end
		end
		resources :startpages do
			collection do
				get 'unauthorized'
			end
		end

		resources :user_accounts do
			collection do
				post 'change_password'
				put 'change_password'
				get 'get_email_addresses'
				get 'get_spamassassin_settings'
				get 'get_vacation_settings'
				get 'get_user_rights'
				post 'set_mail_setting'
			end
		end

		resources :graph_data_sets do
			member do
				get 'render_graph'
			end
		end

		resources :ipv6_routes do
			collection do
				get 'render_graph'
			end
		end

		resources :bills do
			member do
				patch 'save_time_elements'
				get 'get_pdf'
			end
		end

		res.uniq.each do |r|
			resources r # do
				#collection do
					#post 'search'
					#get 'search'
				#end
			#end	
		end

	end

	#match '/icons' => 'icons#show_icons', via: [:get]
	match '/:locale' => 'startpages#index', via: [:get]

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'startpages#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':locale/:controller(/:action(/:id))(.:format)', via: [:get]
end
