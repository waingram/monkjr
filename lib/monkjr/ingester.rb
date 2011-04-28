require 'om'

class Monkjr::Ingester
  attr_accessor :package_dir

  def initialize(package_dir)
    self.package_dir = package_dir
  end

  def ingest
    puts "Ingesting from #{self.package_dir}"

    Dir.entries(package_dir).each do |f|
      next if File.directory?(f)

      item = create_item(f)

    end
  end

  def create_item(file)
    puts "Processing #{file}..."
    begin
      tei_xml        = package_file_xml(file)
      tei_header_xml = get_tei_header_xml(tei_xml)
      title          = get_title(tei_xml)
      tcpid          = get_tcpid(tei_xml)
      pid            = tcpid_to_pid(tcpid)

      replacing_object(pid) do
        tcp_asset                                               = Monkjr::TcpAsset.new(:pid => pid)
        tcp_asset.datastreams['teiHeader'].ng_xml               = tei_header_xml
        tcp_asset.datastreams['teiHeader'].attributes[:dsLabel] = "TEI Header"

        tei_ds = ActiveFedora::Datastream.new(:dsId => "TEI", :dsLabel => "TEI XML", :controlGroup => "M", :blob => File.open(package_file(file)))
        tcp_asset.add_datastream(tei_ds)

        tcp_asset.datastreams['properties'].title_values << title
        tcp_asset.label = title

        tcp_asset.save
        tcp_asset
      end
    rescue Exception => e
      puts "[ERROR] #{e.message}"
    end

  end

  def package_file(*args)
    File.join(package_dir, *args)
  end

  def package_file_contents(*args)
    File.read(package_file(*args))
  end

  def package_file_xml(*args)
    Nokogiri::XML::Document.parse(package_file_contents(*args))
  end

  def get_tcpid(tei_xml)
    #tcpid = tei_xml.xpath("//tei:idno[@type='TCP']/text" 'tei' => 'http://www.tei-c.org/ns/1.0')
    tcpid = tei_xml.css("TEI > teiHeader > fileDesc > publicationStmt > idno[type='TCP']").text
    raise "Can't get tcpid." if tcpid.blank?
    tcpid
  end

  def get_tei_header_xml(tei_xml)
    tei_xml.css("TEI > teiHeader")
  end

  def get_title(tei_xml)
    tei_xml.css("TEI > teiHeader > fileDesc > titleStmt > title").text
  end

  def tcpid_to_pid(tcpid)
    "bamboo:#{tcpid}"
  end

  def replacing_object(pid)
    begin
      object = ActiveFedora::Base.load_instance(pid)
      puts "Replacing object: #{pid}"
      object.delete unless object.nil?
    rescue ActiveFedora::ObjectNotFoundError
      puts "Creating new object: #{pid}"
    end
    yield
  end

end
