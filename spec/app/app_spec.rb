require File.dirname(__FILE__) + '/../spec_helper'
require 'taskwarrior-web'

set :environment, :test

describe TaskwarriorWeb::App do
  include Rack::Test::Methods

  def app
    TaskwarriorWeb::App
  end

  before do
    TaskwarriorWeb::Config.should_receive(:property).with('task-web.user').any_number_of_times.and_return(nil)
    TaskwarriorWeb::Config.should_receive(:property).with('task-web.filter').any_number_of_times.and_return(nil)
    TaskwarriorWeb::Runner.should_receive(:run).any_number_of_times.and_return('{}')
  end

  ['/', '/tasks'].each do |path|
    describe "GET #{path}" do
      it 'should redirect to /tasks/pending' do
        get path
        follow_redirect!

        last_request.url.should match(/tasks\/pending$/)
        last_response.should be_ok
      end
    end
  end

  describe 'GET /tasks/new' do
    it 'should display a new task form' do
      get '/tasks/new'
      last_response.body.should include('<form')
    end

    it 'should display a 200 status code' do
      get '/tasks/new'
      last_response.should be_ok
    end
  end

  describe 'POST /tasks' do
    context 'given a valid task' do
      it 'should save the task' do
        task = TaskwarriorWeb::Task.new({:description => 'Test task'})
        task.should_receive(:save!).once
        TaskwarriorWeb::Task.should_receive(:new).once.and_return(task)
        post '/tasks', :task => {:description => 'Test task'}
      end

      it 'should redirect to the task listing page' do
        task = TaskwarriorWeb::Task.new({:description => 'Test task'})
        task.should_receive(:is_valid?).and_return(true)
        task.should_receive(:save!)
        TaskwarriorWeb::Task.should_receive(:new).once.and_return(task)
        post '/tasks', :task => {:description => 'Test task'}
        follow_redirect!
        last_request.url.should match(/tasks$/)
      end
    end

    context 'given an invalid task' do
      it 'should not save the task' do
        task = TaskwarriorWeb::Task.new
        task.should_not_receive(:save!)
        TaskwarriorWeb::Task.should_receive(:new).once.and_return(task)
        post '/tasks', :task => {}
      end

      it 'should render the task form' do
        task = TaskwarriorWeb::Task.new({:tags => 'tag1, tag2'})
        TaskwarriorWeb::Task.should_receive(:new).once.and_return(task)
        post '/tasks', :task => {}
        last_response.body.should include('form')
        last_response.body.should include('tag1, tag2')
      end

      it 'should display errors messages' do
        task = TaskwarriorWeb::Task.new
        TaskwarriorWeb::Task.should_receive(:new).once.and_return(task)
        post '/tasks', :task => {}
        last_response.body.should include('You must provide a description')
      end
    end
  end

  describe 'GET /tasks/:uuid' do
    context 'given a non-existant task' do
      it 'should return a 404' do
        TaskwarriorWeb::Task.should_receive(:find_by_uuid).and_return([])
        get '/tasks/1'
        last_response.should be_not_found
      end
    end

    context 'given an existing task' do
      before do
        TaskwarriorWeb::Task.should_receive(:find_by_uuid).and_return([
          TaskwarriorWeb::Task.new({:description => 'Test task with a longer description', :tags => ['test', 'tag']})
        ])
      end

      it 'should render an edit form'
      it 'should truncate the task description'
      it 'should fill the form fields with existing data'
    end
  end

  describe 'PATCH /tasks/:uuid' do
    context 'given a non-existant task' do
      it 'should return a 404' do
        TaskwarriorWeb::Task.should_receive(:find_by_uuid).and_return([])
        patch '/tasks/429897527'
        last_response.should be_not_found
      end
    end
  end

  describe 'GET /tasks/:uuid/delete' do
    context 'given a non-existant task' do
      it 'should return a 404' do
        TaskwarriorWeb::Task.should_receive(:find_by_uuid).and_return([])
        get '/tasks/429897527/delete'
        last_response.should be_not_found
      end
    end
  end

  describe 'DELETE /tasks/:uuid' do
    context 'given a non-existant task' do
      it 'should return a 404' do
        TaskwarriorWeb::Task.should_receive(:find_by_uuid).and_return([])
        delete '/tasks/429897527'
        last_response.should be_not_found
      end
    end
  end

  describe 'GET /projects' do
    it 'should redirect to /projects/overview' do
      get '/projects'
      follow_redirect!

      last_request.url.should match(/projects\/overview$/)
      last_response.should be_ok
    end
  end

  describe 'GET /projects/:name' do
    it 'should replace characters in the title' do
      TaskwarriorWeb::Task.should_receive(:query).any_number_of_times.and_return([])
      get '/projects/Test--Project'
      last_response.body.should include('<title>Test.Project')
    end
  end

  describe 'GET /ajax/projects' do
    it 'should return a list of projects as JSON' do
      command = TaskwarriorWeb::Command.new(:projects)
      command.should_receive(:run).and_return("Project One\nProject Two")
      TaskwarriorWeb::Command.should_receive(:new).with(:projects).and_return(command)
      get '/ajax/projects'
      last_response.body.should eq(['Project One', 'Project Two'].to_json)
    end
  end

  describe 'GET /ajax/count' do
    it 'should return the current pending task count' do
      TaskwarriorWeb::Task.should_receive(:count).and_return(15)
      get '/ajax/count'
      last_response.body.should eq('15')
    end
  end

  describe 'POST /ajax/task-complete/:id' do
    it 'should mark the given task as complete' do
      command = TaskwarriorWeb::Command.new(:complete, 15)
      command.should_receive(:run).once
      TaskwarriorWeb::Command.should_receive(:new).once.with(:complete, '15').and_return(command)
      post '/ajax/task-complete/15'
      last_response.should be_ok
    end
  end

  describe 'not_found' do
    it 'should set the title to "Not Found"' do
      get '/page-not-found'
      last_response.body.should include('<title>Page Not Found')
    end

    it 'should have a status code of 404' do
      get '/page-not-found'
      last_response.should be_not_found
    end
  end
end
