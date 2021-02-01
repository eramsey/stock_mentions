require 'httparty'
require 'yaml'

class YoutubePuller
  attr_accessor :channels
  attr_reader :api_key, :base, :verbose

  def check_channels
    raise 'No channels given' unless channels.is_a?(Array) && channels.size > 0
  end

  def pull_configs
    config_file = ARGV[0]
    @config = YAML.load(File.read(config_file.nil? ? "config/config.yaml" : config_file.to_s))
  end

  def initialize(in_channels,verbose=false)
    @channels = in_channels
    @verbose = verbose
    check_channels

    pull_configs

    @base = 'https://youtube.googleapis.com/youtube/v3/commentThreads?part=snippet&pert=replies&maxResults=100&order=time&allThreadsRelatedToChannelId='

    @api_key = @config[:youtube_api_key]

    print "Initialized YouTube Puller with #{channels.size} channels\n"
  end

  def pull_comment_words
    channel_text = {}

    channels.each do |channel_id|
      print channel_id if verbose
      channel_text[channel_id] = []
      url = base + channel_id + '&key=' + api_key

      res = HTTParty.get(url).parsed_response

      unless valid_items?(res)
        print " - no comments\n" if verbose
        next
      end

      print " - #{res["pageInfo"]["totalResults"]}." if verbose

      channel_text[channel_id] << pull_words(res["items"])

      more = res.has_key?('nextPageToken')
      running_total = res["pageInfo"]["totalResults"]

      while more do
        url = base + channel_id + '&pageToken=' + res['nextPageToken'] + '&publishedAfter=' + (Time.now - @config[:comment_days_back]*24*60*60).to_datetime.rfc3339 + '&key=' + api_key
        res = HTTParty.get(url).parsed_response
        break unless valid_items?(res)
        print "#{res["pageInfo"]["totalResults"]}." if verbose
        running_total += res["pageInfo"]["totalResults"]
        channel_text[channel_id] << pull_words(res["items"])
        more = res.has_key?('nextPageToken') && running_total <= @config[:max_comments]
      end
      print "\n" if verbose
    end
    channel_text.values.flatten
  end

  private
  def valid_items?(res)
    res && res["items"] && res["items"].size > 0
  end

  def pull_words(items)
    words = []
    items.each do |i|
      text = i["snippet"]["topLevelComment"]["snippet"]["textDisplay"]
      text_a = text.split
      cap_words = text_a.select{|w|w.upcase == w}
      words << cap_words if text_a.size != cap_words.size
    end
    words
  end

end
