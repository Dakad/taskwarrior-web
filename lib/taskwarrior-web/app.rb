#!/usr/bin/env ruby

require 'sinatra'
require 'erb'
require 'time'
require 'rinku'
require 'digest'
require 'sinatra/simple-navigation'
require 'rack-flash'

class TaskwarriorWeb::App < Sinatra::Base
  autoload :Helpers, 'taskwarrior-web/helpers'

  @@root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
  set :root,  @@root    
  set :app_file, __FILE__
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'
  set :method_override, true
  enable :sessions

  # Helpers
  helpers Helpers
  register Sinatra::SimpleNavigation
  use Rack::Flash
  
  # Before filter
  before do
    @current_page = request.path_info
    @can_edit = TaskwarriorWeb::Config.supports? :editing
    protected! if TaskwarriorWeb::Config.property('task-web.user')
  end

  # Task routes
  get '/tasks/:status/?' do
    pass unless params[:status].in?(%w(pending waiting completed deleted))
    @title = "Tasks"
    if params[:status] == 'pending' && filter = TaskwarriorWeb::Config.property('task-web.filter')
      @tasks = TaskwarriorWeb::Task.query(filter)
    else
      @tasks = TaskwarriorWeb::Task.find_by_status(params[:status])
    end

    case params[:status]
    when ('pending' or 'waiting')
      @tasks.sort_by! { |t| [-t.urgency.to_f, t.priority.nil?.to_s, t.priority.to_s, t.due.nil?.to_s, t.due.to_s, t.project.to_s] }
    when ('completed' or 'deleted')
      @tasks.sort_by! { |t| [Time.parse(t.end)] }.reverse!
    end

    erb :'tasks/index'
  end

  get '/tasks/new/?' do
    @title = 'New Task'
    @date_format = TaskwarriorWeb::Config.dateformat(:js) || 'm/d/yyyy'
    erb :'tasks/new'
  end

  post '/tasks/?' do
    @task = TaskwarriorWeb::Task.new(params[:task])

    if @task.is_valid?
      message = @task.save!
      flash[:success] = message.blank? ? %(New task "#{@task}" created) : message
      redirect to('/tasks')
    end

    flash.now[:error] = @task._errors.join(', ')
    erb :'tasks/new'
  end

  get '/tasks/:uuid/?' do
    not_found unless TaskwarriorWeb::Config.supports?(:editing)
    @task = TaskwarriorWeb::Task.find(params[:uuid]) || not_found
    @title = %(Editing "#{@task}")
    @date_format = TaskwarriorWeb::Config.dateformat(:js) || 'm/d/yyyy'
    erb :'tasks/edit'
  end

  patch '/tasks/:uuid/?' do
    not_found unless TaskwarriorWeb::Config.supports?(:editing) && TaskwarriorWeb::Task.exists?(params[:uuid])

    @task = TaskwarriorWeb::Task.new(params[:task])
    if @task.is_valid?
      message = @task.save!
      flash[:success] = message.blank? ? %(Task "#{@task}" was successfully updated) : message
      redirect to('/tasks')
    end

    flash.now[:error] = @task._errors.join(', ')
    erb :'tasks/edit'
  end

  delete '/tasks/:uuid' do
    not_found unless TaskwarriorWeb::Config.supports?(:editing)
    @task = TaskwarriorWeb::Task.find(params[:uuid]) || not_found
    message = @task.delete!
    flash[:success] = message.blank? ? %(Task "#{@task}" was successfully deleted) : message
    redirect to('/tasks')
  end

  # Projects
  get '/projects/overview/?' do
    @title = 'Projects'
    @tasks = TaskwarriorWeb::Task.query('status.not' => :deleted, 'project.not' => '')
      .sort_by! { |t| [-t.urgency.to_f, t.priority.nil?.to_s, t.priority.to_s, t.due.nil?.to_s, t.due.to_s] }
      .group_by { |t| t.project.to_s }
      .reject { |project, tasks| tasks.select { |task| task.status == 'pending' }.empty? }
    erb :'projects/index'
  end

  get '/projects/:name/?' do
    @title = unlinkify(params[:name])
    @tasks = TaskwarriorWeb::Task.query('status.not' => :deleted, :project => @title)
      .sort_by! { |t| [-t.urgency.to_f, t.priority.nil?.to_s, t.priority.to_s, t.due.nil?.to_s, t.due.to_s] }
    erb :'projects/show'
  end

  # Redirects
  get('/') { redirect to('/tasks/pending') }
  get('/tasks/?') { redirect to('/tasks/pending') }
  get('/projects/?') { redirect to('/projects/overview') }

  # AJAX callbacks
  get('/ajax/projects/?') { TaskwarriorWeb::Command.new(:projects).run.split("\n").to_json }
  get('/ajax/count/?') { task_count }
  post('/ajax/task-complete/:id/?') { TaskwarriorWeb::Command.new(:complete, params[:id]).run }
  get('/ajax/badge/?') { badge_count }

  # Error handling
  not_found do
    @title = 'Page Not Found'
    erb :'404'
  end
end
