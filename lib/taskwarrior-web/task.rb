require 'json'
require 'taskwarrior-web/command'

module TaskwarriorWeb
  
  #################
  # MAIN TASK CLASS
  #################
  class Task

    attr_accessor :entry, :project, :priority, :uuid, :description, :status,
                  :due, :start, :end, :tags, :depends, :wait, :annotations
    alias :annotate= :annotations=

    ####################################
    # MODEL METHODS FOR INDIVIDUAL TASKS
    ####################################

    def initialize(attributes = {})
      attributes.each do |attr, value|
        send("#{attr}=", value) if respond_to?(attr.to_sym)
      end  
    end

    def save!
      Command.new(:add, nil, self.to_hash).run
    end

    # Make sure that the tags are an array.
    def tags=(value)
      @tags = value.is_a?(String) ? value.gsub(', ', ',').split(',') : value
    end

    def to_hash
      Hash[instance_variables.map { |var| [var[1..-1].to_sym, instance_variable_get(var)] }]
    end
    
    ##################################
    # CLASS METHODS FOR QUERYING TASKS
    ##################################

    # Run queries on tasks.
    def self.query(*args)
      tasks = []

      # Process the JSON data.
      json = Command.new(:query, nil, *args).run
      json.strip!
      json = '[' + json + ']'
      results = json == '[No matches.]' ? [] : ::JSON.parse(json)

      results.each { |result| tasks << Task.new(result) }
      tasks
    end

    # Get the number of tasks for some paramters
    def self.count(*args)
      Command.new(:count, nil, *args).run.to_s.strip!
    end

    # Define method_missing to implement dynamic finder methods
    def self.method_missing(method_sym, *arguments, &block)
      match = TaskDynamicFinderMatch.new(method_sym)
      if match.match? 
        self.query(match.attribute.to_s => arguments.first.to_s)
      else
        super
      end
    end
    
    # Implement respond_to? so that our dynamic finders are declared
    def self.respond_to?(method_sym, include_private = false)
      if TaskDynamicFinderMatch.new(method_sym).match?
        true
      else
        super
      end
    end

  end

  ###########################################
  # UTILITY CLASS FOR DYNAMIC FINDER MATCHING
  ###########################################
  class TaskDynamicFinderMatch

    attr_accessor :attribute

    def initialize(method_sym)
      if method_sym.to_s =~ /^find_by_(.*)$/
        @attribute = $1
      end
    end
    
    def match?
      @attribute != nil
    end

  end
end
