require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/config_file'
require 'coffee-script'
require 'twitter'
require 'lastfm'
require 'google_charts'
require 'meta-spotify'
require 'musicbrainz'
require 'koala'
require 'google_visualr'

configure do
  set :lastfm_api_key, ENV['LASTFM_API_KEY']
end

config_file 'config.yml'

get '/' do
  erb :index
end

get '/chart' do
  redirect to('/') unless request.xhr?

  type = (params[:type] || '').to_sym
  halt unless type_valid? type

  bands = parse_csv_omit_empty(params[:bands]).first(3)

  data = send type, bands

  @chart = create_chart(chart_title(type), data)
  @type = type

  erb :chart
end

get '/application.js' do
  coffee :application
end

TYPES = {
  spotify_popularity: 'Spotify Popularity',
  facebook_likes: 'Facebook Likes',
  lastfm_listeners: 'Last.fm Listeners',
  twitter_followers: 'Twitter Followers'
}

def parse_csv_omit_empty(values)
  return [] if values.nil?
  values.strip.split(/\s*,+\s*/).reject(&:empty?)
end

def type_valid?(type)
  TYPES.keys.include? type
end

def chart_title(type)
  TYPES[type]
end

def create_chart(title, data)
  data_table = GoogleVisualr::DataTable.new
  data_table.new_column('string', '')
  data_table.new_column('number', title)
  data_table.add_rows(data)
  options =  {  title: title,
                width: 600,
                height: 250,
                legend: 'none',
                chartArea: { left: '20%' } }
  GoogleVisualr::Interactive::BarChart.new(data_table, options)
end

def facebook_likes(bands)
  graph = Koala::Facebook::API.new
  likes = bands.map do |band|
    begin
      id = nil
      graph.search(band, type: 'page', fields: 'category, id').each do |page_stub|
        if page_stub['category'] == 'Musician/band'
          id = page_stub['id']
          break
        end
      end
      page = graph.get_object(id, fields: 'likes') unless id.nil?
      page['likes'] || 0
    rescue
      0
    end
  end
  bands.zip(likes)
end

def spotify_popularity(bands)
  popularity = bands.map do |band|
    begin
      MetaSpotify::Artist.search(band)[:artists][0].popularity
    rescue
      0
    end
  end
  bands.zip(popularity)
end

def lastfm_listeners(bands)
  unless !settings.lastfm_api_key.nil? && !settings.lastfm_api_key.empty?
    halt
  end

  lastfm = Lastfm.new(settings.lastfm_api_key, nil)
  listeners = bands.map do |band|
    begin
      listeners = lastfm.artist.get_info(band)['stats']['listeners']
      listeners.to_i
    rescue
      0
    end
  end
  bands.zip(listeners)
end

def twitter_followers(bands)
  followers = bands.map do |band|
    begin
      # Searching Twitter by band name is unreliable, the first result is rarely
      # the correct account. Instead, lookup the band's microblog URL on
      # MusicBrainz, if found, it's most likely the URL of the bands Twitter account.
      microblog_url = MusicBrainz::Artist.find_by_name(band).urls[:microblog]
      twitter_username = (/.*twitter.*\/(\w+)\/?$/.match(microblog_url))[1]
      twitter_username ? Twitter.user(twitter_username).followers_count : 0
    rescue
      0
    end
  end
  bands.zip(followers)
end
