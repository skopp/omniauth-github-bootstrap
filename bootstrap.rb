gem('slim-rails')
gem('omniauth-github')
gem('rails_config')

generate('rails_config:install')

client_id = ask('What is your Github Client ID?')
client_secret = ask('What is your Github Client Secret?')

remove_file('config/settings/development.yml')
create_file('config/settings/development.yml') do
<<-EOF
github_oauth:
  client_id: #{client_id}
  client_secret: #{client_secret}
EOF
end

initializer('omniauth.rb') do
<<-EOF
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github, Settings.github_oauth.client_id, Settings.github_oauth.client_secret
end
EOF
end

create_file('app/controllers/welcome_controller.rb') do
<<-EOF
class WelcomeController < ApplicationController
  def index; end
end
EOF
end

#directory('app/views/welcome')
run('mkdir -p app/views/welcome')
create_file('app/views/welcome/index.html.slim') do
<<-EOF
h1 welcome#index
You can find me at app/views/welcome/index.html.slim
EOF
end

create_file('app/controllers/sessions_controller.rb') do
<<-EOF
class SessionsController < ApplicationController

  def create
    user = User.from_omniauth(env['omniauth.auth'])
    session[:user_id] = user.id
    redirect_to root_url, notice: 'Signed in!'
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, notice: 'Signed out!'
  end

end
EOF
end

create_file("db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_create_users.rb") do
<<-EOF
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :uid
      t.string :provider
      t.string :name
      t.string :nickname

      t.timestamps
    end

    add_index :users, [:uid, :provider], unique: true
  end
end
EOF
end

create_file('app/models/user.rb') do
<<-EOF
class User < ActiveRecord::Base

  def self.from_omniauth(auth)
    where(auth.slice('provider', 'uid')).first || create_from_omniauth(auth)
  end

  def self.create_from_omniauth(auth)
    create! do |user|
      user.provider = auth['provider']
      user.uid = auth['uid']
      user.name = auth['info']['name']
      user.nickname = auth['info']['nickname']
    end
  end

end
EOF
end

remove_file('app/controllers/application_controller.rb')
create_file('app/controllers/application_controller.rb') do
<<-EOF
class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :current_user, :logged_in?

private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
  end

  def logged_in?
    !! current_user
  end

  def authenticate!
    redirect_to root_url, 'You can not access this page, you should sign in first.' unless logged_in?
  end

end
EOF
end

remove_file('app/views/layouts/application.html.erb')
create_file('app/views/layouts/application.html.slim') do
<<-EOF
doctype html

html
  head
    title Title

    = stylesheet_link_tag 'application'
    = javascript_include_tag 'application'
    = csrf_meta_tags

  body

    - if logged_in?
      = current_user.name
      /
      = link_to 'Sign out', signout_path
    - else
      = link_to 'Sign in via Github', '/auth/github'

    = yield
EOF
end

route <<-EOF
root to: 'welcome#index'

  match 'auth/:provider/callback', to: 'sessions#create'
  match 'auth/failure', to: redirect('/')
  match 'signout', to: 'sessions#destroy', as: 'signout'
EOF

remove_file('public/index.html')
remove_file('app/assets/images/rails.png')

rake 'db:create db:migrate db:test:prepare'

say("Well done, `#{app_name}` is ready for you. Have a nice day!")
