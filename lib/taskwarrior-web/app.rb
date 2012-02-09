#!/usr/bin/env ruby

require 'sinatra'
require 'erb'
require 'time'
require 'rinku'
require 'taskwarrior-web/config'
require 'taskwarrior-web/helpers'
require 'digest'

module TaskwarriorWeb
  class App < Sinatra::Base

    @@root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
    set :root,  @@root    
    set :app_file, __FILE__
    
    def protected!
      response['WWW-Authenticate'] = %(Basic realm="Taskworrior Web") and throw(:halt, [401, "Not authorized\n"]) and return unless authorized?
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
        @auth.credentials[0] == TaskwarriorWeb::Config.property('task-web.user') &&
        Digest::MD5.hexdigest(@auth.credentials[1]) == TaskwarriorWeb::Config.property('task-web.passwd')
    end

    # Before filter
    before do
      @current_page = request.path_info
      protected! if TaskwarriorWeb::Config.property('task-web.user')
    end

    # Helpers
    helpers TaskwarriorWeb::App::Helpers

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
      @title = "#{params[:status].capitalize} Tasks"
      @subnav = subnav('tasks')
      @tasks = TaskwarriorWeb::Task.find_by_status(params[:status]).sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s, x.project.to_s] }
      erb :listing
    end

    get '/tasks/new/?' do
      @title = 'New Task'
      @subnav = subnav('tasks')
      @date_format = TaskwarriorWeb::Config.dateformat || 'm/d/yy'
      @date_format.gsub!('Y', 'yy')
      erb :task_form
    end

    post '/tasks/new/?' do
      results = passes_validation(params[:task], :task)
      if results.empty?
        task = TaskwarriorWeb::Task.new(params[:task])
        task.save!.to_s
        redirect '/tasks'
      else
        @task = params[:task]
        @messages = []
        results.each do |result|
          @messages << { :severity => 'error', :message => result }
        end
        redirect '/tasks/new'
      end
    end

    # Projects
    get '/projects' do
      redirect '/projects/overview'
    end

    get '/projects/overview/?' do
      @title = 'Projects'
      @subnav = subnav('projects')
      @tasks = TaskwarriorWeb::Task.query('status.not' => 'deleted', 'project.not' => '').sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s] }.group_by { |x| x.project.to_s }
      erb :projects
    end

    get '/projects/:name/?' do
      @subnav = subnav('projects')
      subbed = params[:name].gsub('--', '.') 
      @tasks = TaskwarriorWeb::Task.query('status.not' => 'deleted', :project => subbed).sort_by! { |x| [x.priority.nil?.to_s, x.priority.to_s, x.due.nil?.to_s, x.due.to_s] }
      @title = @tasks.select { |t| t.project.match(/^#{subbed}$/i) }.first.project
      erb :project
    end

    # Reporting
    get '/reports' do
    end

    # AJAX callbacks
    get '/ajax/projects/?' do
      projects = TaskwarriorWeb::Task.query('status.not' => 'deleted').collect { |t| t.project }
      projects.compact.uniq.select {|proj| proj.start_with?(params[:term]) }.to_json
    end

    get '/ajax/tags/?' do
      tags = []
      TaskwarriorWeb::Task.query('status.not' => 'deleted').each do |task|
        tags = tags + task.tags
      end
      tags.compact!.uniq!.to_json
    end

    get '/ajax/count/?' do
      TaskwarriorWeb::Task.count(:status => :pending).to_s
    end

    # Error handling
    not_found do
      @title = 'Page Not Found'
      @referrer = request.referrer
      erb :'404'
    end

    def passes_validation(item, method)
      results = [] 
      case method
        when :task
          if item['description'].empty?
            results << 'You must provide a description'
          end
      end
      results
    end

  end
end
