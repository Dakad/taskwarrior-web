require File.dirname(__FILE__) + '/../spec_helper'
require 'taskwarrior-web/helpers'

RSpec::Mocks::setup(TaskwarriorWeb::Config)

class TestHelpers
  include TaskwarriorWeb::App::Helpers
end

describe TaskwarriorWeb::App::Helpers do
  let(:helpers) { TestHelpers.new }

  describe '#format_date' do
    context 'with no format specified' do
      before do
        TaskwarriorWeb::Config.stub_chain(:file, :get_value).with('dateformat').and_return(nil)
      end

      it 'should format various dates and times to the default format' do
        helpers.format_date('2012-01-11 12:23:00').should == '01/11/2012'
        helpers.format_date('2012-01-11').should == '01/11/2012'
      end
    end

    context 'with a specified date format' do
      before do
        TaskwarriorWeb::Config.stub_chain(:file, :get_value).with('dateformat') { 'd/m/Y' }
      end

      it 'should format dates using the specified format' do
        pending
        helpers.format_date('2012-01-11 12:23:00').should == '11/01/2012'
        helpers.format_date('2012-01-11').should == '11/01/2012'
      end
    end

  end
end

