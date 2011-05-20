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

      book = create_book(f)

    end
  end

  def create_book(file)
    puts "Processing #{file}..."
    begin
      tei_xml        = package_file_xml(file)
      tei_header_xml = get_tei_header_xml(tei_xml)
      title          = get_title(tei_xml)
      tcpid          = get_tcpid(tei_xml)
      pid            = tcpid_to_pid(tcpid)

      replacing_object(pid) do
        tcp_book_asset = Monkjr::TcpBookAsset.new(:pid => pid)
        #TEI header ds
        tei_header_ds                      = tcp_book_asset.datastreams['teiHeader']
        tei_header_ds.ng_xml               = tei_header_xml
        tei_header_ds.attributes[:dsLabel] = "TEI Header"
        #TEI XML
        tei_ds = ActiveFedora::Datastream.new(:dsId => "TEI", :dsLabel => "TEI XML", :controlGroup => "M", :blob => File.open(package_file(file)))
        tcp_book_asset.add_datastream(tei_ds)
        #Properties ds
        tcp_book_asset.datastreams['properties'].title_values << title
        tcp_book_asset.label = title

        tcp_book_asset.save
        #Pages
        create_page_images(tcp_book_asset, tei_xml)
        
        tcp_book_asset
      end
    rescue Exception => e
      puts "[ERROR] #{e.message}"
    end

  end

  def create_page_images(book_obj, tei_xml)
    #doc        = Nokogiri::XML(File.open(tei_xml))
    image_set_id = get_image_set_id(tei_xml)
    page_nodes   = tei_xml.css("pb")
    page_nodes.each do |pn|
      n        = pn['n']
      facs     = pn['facs']
      page_pid = "#{book_obj.pid}.#{facs}"

      page = create_page_image(book_obj, page_pid, image_set_id, n, facs)
      book_obj.add_relationship(:has_part, page)
    end
    book_obj.save
  end

  def create_page_image(book, pid, image_set_id, n="", facs="")
    puts ("Creating page #{facs}")
    replacing_object(pid) do
      tcp_image_asset = Monkjr::TcpPageAsset.new(:pid => pid)
      #properties ds
      props_ds = tcp_image_asset.datastreams['properties']
      props_ds.n_values << n
      props_ds.facs_values << facs
      #content
      image_url = gale_url(facs, image_set_id)
      image_ds  = ActiveFedora::Datastream.new(:dsLabel => "Page image #{facs}", :controlGroup => "E", :dsLocation => image_url)
      tcp_image_asset.add_datastream(image_ds)

      #RELS_EXT
      tcp_image_asset.add_relationship(:is_part_of, book)
      
      tcp_image_asset.save
      tcp_image_asset

    end
  end

  def gale_url(facs, image_set_id)
    intro = "http://callisto.ggsrv.com/imgsrv/Fetch?recordID="

    # there is a case (see K00122.00) where the facs is incorrect
    # instead of the page image sequence number, it is the entire image_set_id + page_num
    # here we account for this case
    if facs.start_with? image_set_id
      page_num = facs[image_set_id.size..-1]
    else
      # otherwise page number needs to be set to four digits, padded with zeros
      page_num = "%04d" % facs
    end

    coda = "0&contentSet=ECLL"

    intro + image_set_id + page_num + coda

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

  def get_image_set_id(tei_xml)
    tei_xml.css("TEI > teiHeader > fileDesc > publicationStmt > idno[type='ImageSetID']").text
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
