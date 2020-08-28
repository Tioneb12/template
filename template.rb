
    # frozen_string_literal: true

# Writing and Reading to files
require 'fileutils'

def add_gems
  gem 'devise'
  gem 'simple_form'
  gem 'friendly_id'
end

def setup_simple_form
  generate 'simple_form:install'
end

def source_paths
  [__dir__]
end

def setup_users
  generate 'devise:install'
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
  generate :devise, 'User', 'username:string:uniq', 'admin:boolean'
  rails_command 'db:migrate'
  generate 'devise:views'

  in_root do
    migration = Dir.glob('db/migrate/*').max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ':admin, default: false'
  end
  inject_into_file 'app/controllers/application_controller.rb', before: 'end' do
    "\n  before_action :configure_permitted_parameters, if: :devise_controller?

    protected
    def configure_permitted_parameters
      added_attrs = %i[username email password password_confirmation remember_me]
      devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
      devise_parameter_sanitizer.permit :account_update, keys: added_attrs
    end\n"
  end

  inject_into_file 'app/models/user.rb', before: 'end' do
    "\n validates :username, presence: true, uniqueness: { case_sensitive: false }
        validate :validate_username
        attr_writer :login

        def login
            @login || username || email
        end

        def validate_username
            errors.add(:username, :invalid) if User.where(email: username).exists?
        end

        def self.find_for_database_authentication(warden_conditions)
            conditions = warden_conditions.dup
            if login = conditions.delete(:login)
                where(conditions.to_hash).where(['lower(username) = :value OR lower(email) = :value', {value: login.downcase}]).first
            elsif conditions.key?(:username) || conditions.key?(:email)
                where(conditions.to_h).first
            end
        end\n"
  end

  inject_into_file 'config/initializers/devise.rb', after: '# config.authentication_keys = [:email]' do
    "\n config.authentication_keys = [:login]\n"
  end

  find_and_replace_in_file('app/views/devise/sessions/new.html.erb', 'email', 'login')

  inject_into_file 'app/views/devise/registrations/new.html.erb', before: '<%= f.input :email' do
    "\n<%= f.input :username %>\n"
  end

  inject_into_file 'app/views/devise/registrations/edit.html.erb', before: '<%= f.input :email' do
    "\n<%= f.input :username %>\n"
  end
end

def find_and_replace_in_file(file_name, old_content, new_content)
  text = File.read(file_name)
  new_contents = text.gsub(old_content, new_content)
  File.open(file_name, 'w') { |file| file.write new_contents }
end

def demo_rails_commands
  generate(:controller, 'pages home')
  route "root to: 'pages#home'"
  rails_command 'g scaffold post title:string body:text --no-scaffold-stylesheet'
  rails_command 'db:migrate'
end


source_paths

add_gems

after_bundle do
  setup_simple_form
  setup_users

  demo_rails_commands

  add_bootstrap
  add_bootstrap_navbar
end
