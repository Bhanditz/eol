# This is, quite simply, a class to round-robin our asset servers, so that their load is equally distributed (in theory).
class ContentServer

  @@next = 0 # This reults in the second entry being used first.  I'm okay with that; it's arbitrary where we begin.
  @@cache_url_re = /(\d{4})(\d{2})(\d{2})(\d{2})(\d+)/

  def self.next
    @@next += 1 
    @@next = 0 if @@next > $CONTENT_SERVERS.length - 1
    return $CONTENT_SERVERS[@@next]
  end

  def self.logo_path(url, size = nil)
    return self.blank if url.blank?
    logo_size = (size == "large") ? "_large.png" : "_small.png"
    if $CONTENT_SERVER_AGENT_LOGOS_PATH =~ /^http/
      "#{$CONTENT_SERVER_AGENT_LOGOS_PATH}#{url}#{logo_size}"
    else
      "#{self.next}#{$CONTENT_SERVER_AGENT_LOGOS_PATH}#{url}#{logo_size}"
    end
    
  end

  def self.cache_path(cache_url, subdir = $CONTENT_SERVER_CONTENT_PATH)
    (self.next + subdir + self.cache_url_to_path(cache_url))
  end

  def self.cache_url_to_path(cache_url)
    new_path = cache_url.to_s.gsub(@@cache_url_re, "/\\1/\\2/\\3/\\4/\\5")
  end

  def self.blank
    "/images/blank.gif"
  end

  def self.uploaded_content_url(url, ext)
    return self.blank if url.blank?
    (self.next + $CONTENT_SERVER_CONTENT_PATH + self.cache_url_to_path(url) + ext)
  end
  
  def self.upload_content(path_from_root, port = nil)
    ip_with_port = $IP_ADDRESS_OF_SERVER.dup
    ip_with_port += ":" + port if port && !ip_with_port.match(/:[0-9]+$/)
    path_from_root = URI.encode(URI.encode(path_from_root))
    parameters = 'function=upload_content&file_path=http://' + ip_with_port + path_from_root
    response = EOLWebService.call(:parameters => parameters)
    if response.blank?
      ErrorLog.create(:url  => $WEB_SERVICE_BASE_URL, :exception_name  => "content partner logo upload service failed") if $ERROR_LOGGING
    else
      response = Hash.from_xml(response)
      if response["response"].class != Hash
        error = "Bad response: #{response["response"]}"
        ErrorLog.create(:url => $WEB_SERVICE_BASE_URL, :exception_name => error, :backtrace => parameters) if $ERROR_LOGGING
      elsif response["response"].key? "file_path"
        return response["response"]["file_path"] # this is the only return other than nil
      elsif response["response"].key? "error"
        error = response["response"]["error"]
        ErrorLog.create(:url => $WEB_SERVICE_BASE_URL, :exception_name => error, :backtrace => parameters) if $ERROR_LOGGING
      end
    end
    nil
  end

end
