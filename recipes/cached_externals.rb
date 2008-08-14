set(:external_modules) do
  require 'yaml'

  modules = YAML.load_file("config/externals.yml") rescue {}
  modules.each do |path, options|
    strings = options.select { |k, v| String === k }
    raise ArgumentError, "the externals.yml file must use symbols for the option keys (found #{strings.inspect} under #{path})" if strings.any?
  end
end

desc "Indicate that externals should be applied locally. See externals:setup."
task :local do
  set :stage, :local
end

namespace :externals do
  desc <<-DESC
    Set up all defined external modules. This will check to see if any of the
    modules need to be checked out (be they new or just updated), and will then
    create symlinks to them. If running in 'local' mode (see the :local task)
    then these will be created in a "../shared/externals" directory relative
    to the project root. Otherwise, these will be created on the remote
    machines under [shared_path]/externals.
  DESC
  task :setup, :except => { :no_release => true } do
    require 'capistrano/recipes/deploy/scm'

    external_modules.each do |path, options|
      puts "configuring #{path}"
      scm = Capistrano::Deploy::SCM.new(options[:type], options)
      revision = scm.query_revision(options[:revision]) { |cmd| `#{cmd}` }

      if exists?(:stage) && stage == :local
        FileUtils.rm_rf(path)
        shared = File.expand_path(File.join("../shared/externals", path))
        FileUtils.mkdir_p(shared)
        destination = File.join(shared, revision)
        if !File.exists?(destination)
          unless system(scm.checkout(revision, destination))
            FileUtils.rm_rf(destination) if File.exists?(destination)
            raise "Error checking out #{revision} to #{destination}"
          end
        end
        FileUtils.ln_s(destination, path)
      else
        shared = File.join(shared_path, "externals", path)
        destination = File.join(shared, revision)
        run "rm -rf #{latest_release}/#{path} && mkdir -p #{shared} && if [ ! -d #{destination} ]; then #{scm.checkout(revision, destination)}; fi && ln -nsf #{destination} #{latest_release}/#{path}"
      end
    end
  end
end

after "deploy:update_code", "externals:setup"
