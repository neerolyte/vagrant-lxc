require 'unit_helper'

require "vendored_vagrant"
require 'vagrant-lxc/container'

describe Vagrant::LXC::Container do
  let(:name) { nil }
  subject { described_class.new(name) }

  describe 'container name validation' do
    let(:unknown_container) { described_class.new('unknown', cli) }
    let(:valid_container)   { described_class.new('valid', cli) }
    let(:new_container)     { described_class.new(nil) }
    let(:cli)               { fire_double('Vagrant::LXC::Container::CLI', list: ['valid']) }

    it 'raises a NotFound error if an unknown container name gets provided' do
      expect {
        unknown_container.validate!
      }.to raise_error(Vagrant::LXC::Container::NotFound)
    end

    it 'does not raise a NotFound error if a valid container name gets provided' do
      expect {
        valid_container.validate!
      }.to_not raise_error(Vagrant::LXC::Container::NotFound)
    end

    it 'does not raise a NotFound error if nil is provider as name' do
      expect {
        new_container.validate!
      }.to_not raise_error(Vagrant::LXC::Container::NotFound)
    end
  end

  describe 'creation' do
    let(:name)            { 'random-container-name' }
    let(:template_name)   { 'template-name' }
    let(:rootfs_cache)    { '/path/to/cache' }
    let(:public_key_path) { Vagrant.source_root.join('keys', 'vagrant.pub').expand_path.to_s }
    let(:cli)             { fire_double('Vagrant::LXC::Container::CLI', :create => true, :name= => true) }

    subject { described_class.new(name, cli) }

    before do
      SecureRandom.stub(hex: name)
      subject.create 'template-name' => template_name, 'rootfs-cache-path' => rootfs_cache, 'template-opts' => { '--foo' => 'bar'}
    end

    it 'creates container with the right arguments' do
      cli.should have_received(:create).with(
        template_name,
        '--auth-key' => public_key_path,
        '--cache'    => rootfs_cache,
        '--foo'      => 'bar'
      )
    end
  end

  describe 'destruction' do
    let(:name) { 'container-name' }
    let(:cli)  { fire_double('Vagrant::LXC::Container::CLI', destroy: true) }

    subject { described_class.new(name, cli) }

    before { subject.destroy }

    it 'delegates to cli object' do
      cli.should have_received(:destroy)
    end
  end

  describe 'start' do
    let(:config) { mock(:config, start_opts: ['a=1', 'b=2']) }
    let(:name)   { 'container-name' }
    let(:cli)    { fire_double('Vagrant::LXC::Container::CLI', start: true) }

    subject { described_class.new(name, cli) }

    before do
      cli.stub(:transition_to).and_yield(cli)
    end

    it 'starts container with configured lxc settings' do
      cli.should_receive(:start).with(['a=1', 'b=2'], nil)
      subject.start(config)
    end

    it 'expects a transition to running state to take place' do
      cli.should_receive(:transition_to).with(:running)
      subject.start(config)
    end
  end

  describe 'halt' do
    let(:name) { 'container-name' }
    let(:cli)  { fire_double('Vagrant::LXC::Container::CLI', shutdown: true) }

    subject { described_class.new(name, cli) }

    before do
      cli.stub(:transition_to).and_yield(cli)
    end

    it 'delegates to cli shutdown' do
      cli.should_receive(:shutdown)
      subject.halt
    end

    it 'expects a transition to running state to take place' do
      cli.should_receive(:transition_to).with(:stopped)
      subject.halt
    end
  end

  describe 'state' do
    let(:name)      { 'random-container-name' }
    let(:cli_state) { :something }
    let(:cli)       { fire_double('Vagrant::LXC::Container::CLI', state: cli_state) }

    subject { described_class.new(name, cli) }

    it 'delegates to cli' do
      subject.state.should == cli_state
    end
  end

  describe 'assigned ip' do
    # This ip is set on the sample-arp-output fixture based on mac address from
    # sample-config fixture
    let(:ip)                 { "10.0.3.30" }
    let(:conf_file_contents) { File.read('spec/fixtures/sample-config') }
    let(:name)               { 'random-container-name' }

    context 'when container mac address gets returned from the first `arp` call' do
      before do
        @arp_output = File.read('spec/fixtures/sample-arp-output')
        subject.stub(:raw) {
          mock(stdout: "#{@arp_output}\n", exit_code: 0)
        }
        File.stub(read: conf_file_contents)
      end

      it 'gets parsed from `arp` based on lxc mac address' do
        subject.assigned_ip.should == ip
        subject.should have_received(:raw).with('arp', '-n')
      end
    end

    pending 'when mac address is not returned from an `arp` call'
  end
end
