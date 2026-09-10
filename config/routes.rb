Rails.application.routes.draw do
  get "/up", to: proc { [200, { "content-type" => "text/plain" }, ["ok"]] }
  get "/api/session", to: "sessions#show"
  post "/api/session", to: "sessions#create"
  delete "/api/session", to: "sessions#destroy"
  scope "/api" do
    resources :projects, only: [:index, :create, :update] do
      post :rotate_invitation, on: :member
      resources :annotations, only: [:index, :show, :update] do
        get :export, on: :collection
        patch :bulk_update, on: :collection
        get :screenshot, on: :member
      end
    end
  end
  get "/api/invitations/:token", to: "invitations#show"
  match "/api/widget/:project_key/*path", to: "widget#preflight", via: :options
  get "/api/widget/:project_key/context", to: "widget#context"
  post "/api/widget/:project_key/annotations", to: "widget#create"
  get "/api/widget/:project_key/annotations/:id", to: "widget#show"
  get "/demo", to: "pages#demo"
  get "/invite/:token", to: "pages#index"
  get "/projects/:project_id/export", to: "pages#index"
  root "pages#index"
end
