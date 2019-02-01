require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

task :lint do
  sh "govuk-lint-ruby lib spec"
end

task default: %i[spec lint]

require_relative './lib/requires'

namespace :deploy do
  task :bouncer do
    DeployBouncer.new.deploy!
  end

  task :dictionaries do
    DeployDictionaries.new.deploy!
  end

  task :service do
    DeployService.new.deploy!
  end
end
