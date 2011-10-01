require 'uri'

class Upload
  include Mongoid::Document
  include Mongoid::Timestamps

  field :guid,          type: String
  field :key,           type: String
  field :name,          type: String
  field :size,          type: Integer
  field :bandwidth,     type: Integer, default: 0
  field :views,         type: Integer, default: 0
  field :type,          type: String
  field :extension,     type: String
  field :kind,          type: String
  field :status,        type: Integer, default: 3
  field :metadata,      type: Hash

  # plupload status:
  # 3=PREPARING
  # 5=DONE

  index :guid, unique: true

  def headers
    {}.tap do |options|
      options["Content-Disposition"] = self.kind == "image" ? "inline" : "attachment"
      options["Content-Disposition"] << "; filename=#{URI.escape(self.name)}"
      options["Content-Type"] = self.type
      options["Cache-Control"] = "public,max-age=31536000"
      options["Expires"] = DateTime.now.next_year.strftime("%a, %d %b %Y %H:%M:%S GMT")
      options["x-amz-acl"] = "public-read"
    end
  end

  def complete(size)
    self.size = size
    self.status = 5
    self
  end
end