require 'monkjr'

class TcpAsset < ActiveFedora::Base
  
  has_metadata :name => 'teiHeader', :type => ActiveFedora::NokogiriDatastream

  has_metadata :name => 'properties', :type => ActiveFedora::MetadataDatastream do |p|
    p.field 'title', :string
  end

  def initialize( attrs={} )
    super(attrs)
    #add_relationship(:has_model, 'monkjr-cModel:basicAsset')
  end

end
