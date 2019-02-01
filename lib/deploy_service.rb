class DeployService
  CONFIGS = YAML.load_file(File.join(__dir__, "..", "fastly.yaml"))

  def deploy!
    service_name = ENV.fetch("SERVICE_NAME")
    environment = ENV.fetch("ENVIRONMENT")

    @fastly = FastlyClient.client
    config['git_version'] = get_git_version

    service = @fastly.get_service(config['service_id'])
    version = get_dev_version(service)
    puts "Current version: #{version.number}"
    puts "Configuration: #{service_name}"
    puts "Environment: #{environment}"

    vcl = RenderTemplate.render_template(service_name, environment, config)
    delete_ui_objects(service.id, version.number)
    upload_vcl(version, vcl)
    diff_vcl(service, version)

    modify_settings(version, config['default_ttl'])

    validate_config(version)
    version.activate!
  end

private

  def config
    @config ||= begin
      service_name = ENV.fetch("SERVICE_NAME")
      environment = ENV.fetch("ENVIRONMENT")
      CONFIGS[service_name][environment] || raise("Unknown service/environment combination")
    end
  end

  def get_git_version
    ref = %x{git describe --always}.chomp
    ref = "unknown" if ref.empty?

    ref
  end

  def get_dev_version(service)
    # Sometimes the latest version isn't the development version.
    version = service.version
    version = version.clone if version.active?

    version
  end

  def delete_ui_objects(service_id, version_number)
    # Delete objects created by the UI. We want VCL to be the source of truth.
    # Most of these don't have real objects in the Fastly API gem.
    to_delete = %w{backend healthcheck cache_settings request_settings response_object header gzip}
    to_delete.each do |type|
      type_path = "/service/#{service_id}/version/#{version_number}/#{type}"
      @fastly.client.get(type_path).map { |i| i["name"] }.each do |name|
        puts "Deleting #{type}: #{name}"
        resp = @fastly.client.delete("#{type_path}/#{ERB::Util.url_encode(name)}")
        raise 'ERROR: Failed to delete configuration' unless resp
      end
    end
  end

  def modify_settings(version, ttl)
    settings = version.settings
    settings.settings.update(
      "general.default_host" => "",
      "general.default_ttl"  => ttl,
    )
    settings.save!
  end

  def upload_vcl(version, contents)
    vcl_name = 'main'

    begin
      version.vcl(vcl_name) && version.delete_vcl(vcl_name)
    rescue Fastly::Error => e
      puts e.inspect
    end

    vcl = version.upload_vcl(vcl_name, contents)
    @fastly.client.put(Fastly::VCL.put_path(vcl) + '/main')
  end

  def diff_vcl(service, version_new)
    version_current = service.versions.find(&:active?)

    if version_current.nil?
      raise 'There are no active versions of this configuration'
    end

    diff = Diffy::Diff.new(
      version_current.generated_vcl.content,
      version_new.generated_vcl.content,
      context: 3
    )

    puts "Diff versions: #{version_current.number} -> #{version_new.number}"
    puts diff.to_s(:color)
  end

  def validate_config(version)
    unless version.validate
      raise "ERROR: Invalid configuration:\n" + valid_hash.fetch('msg')
    end
  end
end