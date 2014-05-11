require 'coveralls'
Coveralls.wear!

require 'guard'
require 'rspec'

ENV["GUARD_ENV"] = 'test'

Dir["#{File.expand_path('..', __FILE__)}/support/**/*.rb"].each { |f| require f }

puts "Please do not update/create files while tests are running."

RSpec.configure do |config|
  config.color_enabled = true
  config.order = :random
  config.filter_run focus: ENV['CI'] != 'true'
  config.run_all_when_everything_filtered = true
  config.raise_errors_for_deprecations!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    @fixture_path = Pathname.new(File.expand_path('../fixtures/', __FILE__))

    # Ensure debug command execution isn't used in the specs
    allow(Guard).to receive(:_debug_command_execution)

    # Stub all UI methods, so no visible output appears for the UI class
    allow(::Guard::UI).to receive(:info)
    allow(::Guard::UI).to receive(:warning)
    allow(::Guard::UI).to receive(:error)
    allow(::Guard::UI).to receive(:debug)
    allow(::Guard::UI).to receive(:deprecation)

    # Avoid clobbering the terminal
    allow(Guard::Notifier::TerminalTitle).to receive(:puts)
    allow(Guard::Notifier::Tmux).to receive(:system) { '' }
    allow(Guard::Notifier::Tmux).to receive(:`) { '' }
    allow(Pry.output).to receive(:puts)

    ::Guard.reset_groups
    ::Guard.reset_plugins

    interactor = Guard.instance_variable_get('@interactor')
    if interactor
      interactor.stop
      Guard.remove_instance_variable('@interactor')
    end
  end

  config.before(:suite) do
    # Use a fake home directory so that user configurations,
    # such as their ~/.guard.rb file, won't impact the
    # tests.
    fake_home = File.expand_path('../fake-home', __FILE__)
    FileUtils.rmtree fake_home
    FileUtils.mkdir  fake_home
    ENV['HOME'] = fake_home
  end

  config.before(:all) do
    @guard_notify ||= ENV['GUARD_NOTIFY']
    @guard_notifiers ||= ::Guard::Notifier.notifiers
  end

  config.after(:each) do
    interactor = Guard.instance_variable_get('@interactor')
    if interactor
      interactor.stop
      sleep 1
      Guard.remove_instance_variable('@interactor')
    end

    Pry.config.hooks.delete_hook(:when_started, :load_guard_rc)
    Pry.config.hooks.delete_hook(:when_started, :load_project_guard_rc)

    Guard::Notifier.clear_notifiers

    ::Guard.options[:debug] = false if ::Guard.options
  end

  config.after(:all) do
    ENV['GUARD_NOTIFY'] = @guard_notify
    ::Guard::Notifier.notifiers = @guard_notifiers
  end

end
