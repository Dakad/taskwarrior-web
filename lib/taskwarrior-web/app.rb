#!/usr/bin/env ruby

require 'sinatra'
require 'erb'
require 'time'
require 'rinku'
require 'digest'
require 'sinatra/simple-navigation'

class TaskwarriorWeb::App < Sinatra::Base
  autoload :Helpers, 'taskwarrior-web/helpers'

  @@root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
  set :root,  @@root    
  set :app_file, __FILE__
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

  # Helpers
  helpers Helpers
  register Sinatra::SimpleNavigation
  
  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Taskworrior Web") and throw(:halt, [401, "Not authorized\n"]) and return unless authorized?
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    values = [TaskwarriorWeb::Config.property('task-web.user'), TaskwarriorWeb::Config.property('task-web.passwd')]
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == values
  end

  # Before filter
  before do
    @current_page = request.path_info
    protected! if TaskwarriorWeb::Config.property('task-web.user')
  end

  # Redirects
  get '/' do
    redirect '/tasks/pending'
  end
  get '/tasks/?' do
    redirect '/tasks/pending'
  end

  # Task routes
  get '/tasks/:status/?' do
    pass unless ['pending', 'waiting', 'completed', 'deleted'].include?(params[:status])
    @title = "Tasks"
    @tasks = TaskwarriorWeb::Task.find_by_status(params[:status]).sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s, x.project.to_s] }
    erb :listing
  end

  get '/tasks/new/?' do
    @title = 'New Task'
    @date_format = (TaskwarriorWeb::Config.dateformat || 'm/d/yy').gsub('Y', 'yy')
    erb :task_form
  end

  post '/tasks/?' do
    @task = TaskwarriorWeb::Task.new(params[:task])

    if @task.is_valid?
      @task.save!
      redirect '/tasks'
    end

    @messages = @task._errors.map { |error| { :severity => 'alert-error', :message => error } }
    call! env.merge('REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/tasks/new')
  end

  # Projects
  get '/projects' do
    redirect '/projects/overview'
  end

  get '/projects/overview/?' do
    @title = 'Projects'
    @tasks = TaskwarriorWeb::Task.query('status.not' => :deleted, 'project.not' => '')
      .sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s] }
      .group_by { |x| x.project.to_s }
      .reject { |project, tasks| tasks.select { |task| task.status == 'pending' }.empty? }
    erb :projects
  end

  get '/projects/:name/?' do
    subbed = params[:name].gsub('--', '.') 
    @tasks = TaskwarriorWeb::Task.query('status.not' => 'deleted', :project => subbed)
      .sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s] }
    @title = @tasks.select { |t| t.project.match(/^#{subbed}$/i) }.first.project
    erb :project
  end

  # AJAX callbacks
  get '/ajax/projects/?' do
    TaskwarriorWeb::Command.new(:projects).run.split("\n").to_json
  end

  get '/ajax/count/?' do
    TaskwarriorWeb::Task.count(:status => :pending).to_s
  end

  post '/ajax/task-complete/:id/?' do
    # Bummer that we have to directly use Command here, but apparently tasks
    # cannot be filtered by UUID.
    TaskwarriorWeb::Command.new(:complete, params[:id]).run
  end

  # Error handling
  not_found do
    @title = 'Page Not Found'
    @referrer = request.referrer
    erb :'404'
  end
end
