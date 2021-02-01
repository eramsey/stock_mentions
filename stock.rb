#!/usr/local/rvm/rubies/ruby-2.6.1/bin/ruby
require 'yaml'
require 'discord_notifier'
require 'text-table'
require './lib/youtube_puller.rb'

start_time = Time.now

config_file = ARGV[0]
config = YAML.load(File.read(config_file.nil? ? "config/config.yaml" : config_file))
print config[:discord_bot_name] + "\n"

channel_text = {}

next_page_token = nil
more = false

yt = YoutubePuller.new(config[:channels],true)
a = yt.pull_comment_words

current_pull = File.open('tmp/current_pull.txt','w')
current_pull.print a.join(' ')

nyse_a = CSV.open('listings/nyse-listed.csv').to_a
nyse_a.delete_at(0)
nyse_h = nyse_a.to_h
nyse_tickers = nyse_h.keys
missing_tickers = nyse_tickers - a
found_tickers = (nyse_tickers - missing_tickers).select{|ticker|ticker.size > 1}

counts = Hash[found_tickers.map{|v|[v,0]}]

common_words = File.readlines('listings/common_stock_words.txt').map!(&:strip)

found_tickers.each do |ticker|
  counts[ticker] += a.select{|w|w == "$" + ticker || (!common_words.include?(w) && w == ticker)}.size
end

table_array = [['Stock','Mentions']]

print "Sending to Discord...\n"
counts.sort_by{|k,v|v}.reverse.to_h.each_pair do |k,v|
  next unless v > config[:counts_greater_than]
  print "#{k}\t#{v}\n"
  table_array << [k,v]
end

Discord::Notifier.setup do |discord_config|
  discord_config.url = config[:discord_webhook]
  discord_config.username = config[:discord_bot_name]
  discord_config.avatar_url = ''
  discord_config.wait = true
end

dur = Time.now - start_time
print "duration: #{format("%02d:%02d:%02d", dur / (60 * 60), (dur / 60) % 60, dur % 60)}\n"

Discord::Notifier.message('```'+table_array.to_table(:first_row_is_head => true).to_s+'```'+"NYSE Only at this time\nduration: #{format("%02d:%02d:%02d", dur / (60 * 60), (dur / 60) % 60, dur % 60)}\n")

