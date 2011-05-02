class Monkjr::TcpPageAsset < ActiveFedora::Base

  has_metadata :name => 'properties', :type => ActiveFedora::MetadataDatastream do |p|
    p.field 'n', :string
    p.field 'facs', :string
  end

  def initialize(attrs={})
    super(attrs)
    #add_relationship(:has_model, 'monkjr-cModel:basicAsset')
  end

end