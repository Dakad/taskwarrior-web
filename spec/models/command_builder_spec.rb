require File.dirname(__FILE__) + '/../spec_helper'
require 'taskwarrior-web/command_builder'

RSpec::Mocks::setup(TaskwarriorWeb::Config)

describe TaskwarriorWeb::CommandBuilder do
  describe '.included' do
    context 'when v2 is reported' do
      it 'should include CommandBuilder V2 module' do
        TaskwarriorWeb::Config.should_receive(:task_version).and_return('2.0.1')
        TestCommandClass.class_eval { include TaskwarriorWeb::CommandBuilder }
        TestCommandClass.included_modules.should include(TaskwarriorWeb::CommandBuilder::V2)
      end
    end

    context 'when v1 is reported' do
      it 'should include CommandBuilder V1 module' do
        TaskwarriorWeb::Config.should_receive(:task_version).and_return('1.9.4')
        TestCommandClass.class_eval { include TaskwarriorWeb::CommandBuilder }
        TestCommandClass.included_modules.should include(TaskwarriorWeb::CommandBuilder::V1)
      end
    end

    context 'when an invalid version number is reported' do
      it 'should throw an UnrecognizedTaskVersion exception' do
        TaskwarriorWeb::Config.should_receive(:task_version).and_return('95.583.3')
        expect { 
          TestCommandClass.class_eval { include TaskwarriorWeb::CommandBuilder }
        }.should raise_exception(TaskwarriorWeb::UnrecognizedTaskVersion)
      end
    end
  end
end

class TestCommandClass; end

module TaskwarriorWeb::CommandBuilder::V2; end
