require 'monkjr'
require 'active-fedora'

desc 'Ingest TCP files'
task :ingest => :environment do
  package_dir = ENV['INGEST_SOURCE_DIR']
  raise "Define environment variable INGEST_SOURCE_DIR" unless package_dir
    
  # If a destination url has been provided, attampt to export from the fedora repository there.
  if ENV["destination"]
    Fedora::Repository.register(ENV["destination"])
  end
                     
  # If Fedora Repository connection is not already initialized, initialize it using ActiveFedora defaults
    ActiveFedora.init unless Thread.current[:repo]
  

  Monkjr::Ingester.new(package_dir).ingest
end
