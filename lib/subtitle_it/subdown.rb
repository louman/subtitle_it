## downsub - github.com/johanlunds/downsub
require 'xmlrpc/client'
require 'zlib'
require 'stringio'

require 'subtitle_it/version'
require 'subtitle_it/subtitle'
require 'subtitle_it/languages'

module SubtitleIt
  class Subdown
    HOST = "http://api.opensubtitles.org/xml-rpc"
    HOST_DEV = "http://dev.opensubtitles.org/xml-rpc"

   # USER_AGENT = "SubDownloader #{SubtitleIt::VERSION::STRING}"
    USER_AGENT = "SubtitleIt #{SubtitleIt::VERSION::STRING}"

    NO_TOKEN = %w(ServerInfo LogIn)

    def initialize(host = HOST)
      @client = XMLRPC::Client.new2(host)
      @token = nil
    end

    def log_in!
      result = request('LogIn', '', '', '', USER_AGENT)
      @token = result['token'].to_s
    end

    def logged_in?
      !@token.nil? && !@token.empty?
    end

    def log_out!
      request('LogOut')
      @token = nil
    end

    def server_info
      request('ServerInfo')
    end

    def search_subtitles(movie, lang_name=nil)
      # lang_name, lang_code = LANGS[lang_id.to_sym] if lang_id
      # print "Searching for "
      # puts lang_id ? lang_name + "..." : "all languages."
      args = {
        'sublanguageid' => lang_name || "",
        'moviehash'     => movie.haxx,
        'moviebytesize' => movie.size
      }

      result = request('SearchSubtitles', [args])
      binding.pry
      return [] unless result['data'] # if no results result['data'] == false
      result['data'].inject([]) do |subs, sub_info|
        subs << Subtitle.new({:info => sub_info})
        subs
      end
    end

    def download_subtitle(sub)
      result = request('DownloadSubtitles', [sub.osdb_id])
      sub.data = self.class.decode_and_unzip(result['data'][0]['data'])
    end

    def upload_subtitle(movie, subs)
    end

    def imdb_info(movie)
      result = request('CheckMovieHash', [movie.haxx])
      movie.info = result['data'][movie.haxx] # TODO: Handle if no result for movie
    end

    def self.subtitle_languages
      LANGS.map do |k, v|
        "#{k} -> #{v}"
      end.join("\n")
    end

    private

    def request(method, *args)

      unless NO_TOKEN.include? method
        raise 'Need to be logged in for this.' unless logged_in?
        args = [@token, *args]
      end

            p method, args
      result = @client.call(method, *args)
      p result
      # $LOG.debug "Client#call #{method}, #{args.inspect}: #{result.inspect}"

      unless self.class.result_status_ok?(result)
        raise XMLRPC::FaultException.new(result['status'].to_i, result['status'][4..-1]) # 'status' of the form 'XXX Message'
      end

      result
    end

    # Returns true if status is OK (ie. in range 200-299) or don't exists.
    def self.result_status_ok?(result)
      !result.key?('status') || (200...300) === result['status'].to_i
    end

    def prevent_session_expiration
      request('NoOperation')
    end

    def self.decode_and_unzip(data)
      Zlib::GzipReader.new(StringIO.new(XMLRPC::Base64.decode(data))).read
    end
  end
end
