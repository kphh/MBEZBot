require 'net/http'
require 'json'
require 'twitter'

# top left Myrtle/Throop 40.69621, -73.94377
# bottom right Putnam/Broadway 40.68757, -73.91875
# stations = res['data']['stations'].select { |st| st['lat'] <= 40.69621 && st['lat'] >= 40.68757 && st['lon'] <= -73.91875 && st['lon'] >= -73.94377 }

# westernmost Willoughby and Wsh Park -73.97378173414944
# easternmost Forest & Summerfield -73.89771454982606
# southernmost Sterling St & Bedford 40.66254075631774
# northernmost Adelphi & Myrtle 40.693405212520304


def lambda_handler(event:, context:)
  # bust stations cache between tweets but reuse rather than rerunning the select for each call to #stations
  @stations = nil

  latest_tweet = tweet
  { statusCode: 200, body: JSON.generate("Posted Tweet ID #{latest_tweet.id} at #{latest_tweet.created_at}") }
end

def tweet
  twitter_client.update tweet_body
end

private

def twitter_client
  @twitter_client ||= Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['CONSUMER_KEY']
    config.consumer_secret     = ENV['CONSUMER_SECRET']
    config.access_token        = ENV['ACCESS_TOKEN']
    config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
  end
end

def tweet_body
  "#{num_bikes_available} bikes (including #{num_ebikes_available} ebikes) are available of a possible #{num_active_docks}. " +
  "#{percent_empty_docks.round(1)}% of active docks are empty. " +
  "At least #{empty_stations.count} of #{renting_stations.count} active stations have 0 available bikes. " +
  "#{disabled_stations.count} stations are disabled."
end

# every station in the entire CitiBike system
def all_stations
  if @all_stations.nil?
    @all_stations = JSON.parse(Net::HTTP.get(URI("https://gbfs.citibikenyc.com/gbfs/en/station_status.json")))
  elsif Time.now.to_i - @all_stations["last_updated"] > 120
    @all_stations = JSON.parse(Net::HTTP.get(URI("https://gbfs.citibikenyc.com/gbfs/en/station_status.json")))      
  end

  @all_stations
end

def stations
  @stations ||= all_stations['data']['stations'].select do |station|
    station_ids.include? station['station_id']
  end
end

def renting_stations
  stations.select do |station|
    station['is_renting'] == 1
  end
end

def empty_stations
  renting_stations.select do |station|
    station['num_bikes_available'] == 0
  end
end

def disabled_stations
  stations.select do |station|
    station['is_renting'] == 0
  end
end

def num_bikes_available
  renting_stations.map do |station|
    station['num_bikes_available']
  end.inject(:+)
end

def num_ebikes_available
  renting_stations.map do |station|
    station['num_ebikes_available']
  end.inject(:+)
end

def num_total_docks
  stations.map do |station|
    [station['num_bikes_available'], station['num_bikes_disabled'], 
    station['num_docks_available'], station['num_docks_disabled']]
  end.flatten.inject(:+)
end

def num_active_docks
  renting_stations.map do |station|
    [station['num_bikes_available'], station['num_bikes_disabled'], 
    station['num_docks_available'], station['num_docks_disabled']]
  end.flatten.inject(:+)
end

def percent_empty_docks
  (1 - (num_bikes_available.to_f / num_active_docks)) * 100
end

# westernmost Willoughby and Wsh Park -73.97378173414944
# easternmost Forest & Summerfield -73.89771454982606
# southernmost Sterling St & Bedford 40.66254075631774
# northernmost Adelphi & Myrtle 40.693405212520304
def station_ids
  [
    "120", # "Lexington Ave & Classon Ave"
   "244", # "Willoughby Ave & Hall St"
   "258", # "DeKalb Ave & Vanderbilt Ave"
   "262", # "Washington Park"
   "270", # "Adelphi St & Myrtle Ave"
   "275", # "Washington Ave & Greene Ave"
   "289", # "Monroe St & Classon Ave"
   "344", # "Monroe St & Bedford Ave"
   "364", # "Lafayette Ave & Classon Ave"
   "366", # "Clinton Ave & Myrtle Ave"
   "373", # "Willoughby Ave & Walworth St"
   "396", # "Lefferts Pl & Franklin Ave"
   "397", # "Fulton St & Clermont Ave"
   "399", # "Lafayette Ave & St James Pl"
   "416", # "Cumberland St & Lafayette Ave"
   "420", # "Clermont Ave & Lafayette Ave"
   "436", # "Hancock St & Bedford Ave"
   "437", # "Macon St & Nostrand Ave"
   "3041", # "Kingston Ave & Herkimer St"
   "3042", # "Fulton St & Utica Ave"
   "3043", # "Lewis Ave & Decatur St"
   "3044", # "Albany Ave & Fulton St"
   "3046", # "Marcus Garvey Blvd & Macon St"
   "3047", # "Halsey St & Tompkins Ave"
   "3048", # "Putnam Ave & Nostrand Ave"
   "3049", # "Cambridge Pl & Gates Ave"
   "3050", # "Putnam Ave & Throop Ave"
   "3052", # "Lewis Ave & Madison St"
   "3053", # "Marcy Ave & Lafayette Ave"
   "3054", # "Greene Ave & Throop Ave"
   "3055", # "Greene Ave & Nostrand Ave"
   "3056", # "Kosciuszko St & Nostrand Ave"
   "3057", # "Kosciuszko St & Tompkins Ave"
   "3058", # "Lewis Ave & Kosciuszko St"
   "3059", # "Pulaski St & Marcus Garvey Blvd"
   "3241", # "Monroe St & Tompkins Ave"
   "3249", # "Verona Pl & Fulton St"
   "3349", # "Grand Army Plaza & Plaza St West"
   "3354", # "3 St & Prospect Park West"
   "3416", # "7 Ave & Park Pl"
   "3418", # "Plaza St West & Flatbush Ave"
   "3537", # "Carlton Ave & Dean St"
   "3544", # "Underhill Ave & Pacific St"
   "3546", # "Pacific St & Classon Ave"
   "3549", # "Grand Ave & Bergen St"
   "3558", # "Bergen St & Vanderbilt Ave"
   "3569", # "Franklin Ave & St Marks Ave"
   "3571", # "Bedford Ave & Bergen St"
   "3574", # "Prospect Pl & Underhill Ave"
   "3578", # "Park Pl & Franklin Ave"
   "3579", # "Sterling Pl & Bedford Ave"
   "3580", # "St Johns Pl & Washington Ave"
   "3581", # "Underhill Ave & Lincoln Pl"
   "3582", # "Lincoln Pl & Classon Ave"
   "3583", # "Eastern Pkwy & Washington Ave"
   "3584", # "Eastern Pkwy & Franklin Ave"
   "3585", # "Union St & Bedford Ave"
   "3587", # "Carroll St & Washington Ave"
   "3590", # "Carroll St & Franklin Ave"
   "3596", # "Sullivan Pl & Bedford Ave"
   "3601", # "Sterling St & Bedford Ave"
   "3604", # "Rogers Ave & Sterling St"
   "3637", # "Fulton St & Waverly Ave"
   "3661", # "Montgomery St & Franklin Ave"
   "3673", # "Dean St & Franklin Ave"
   "3755", # "DeKalb Ave & Franklin Ave"
   "3789", # "Fulton St & Irving Pl"
   "3803", # "Bedford Ave & Montgomery St"
   "3824", # "Van Sinderen Ave & Truxton St"
   "3825", # "Broadway & Furman Ave"
   "3826", # "Moffat St & Bushwick"
   "3827", # "Halsey St & Broadway"
   "3828", # "Eldert St & Bushwick Ave"
   "3829", # "Central Ave & Decatur St"
   "3830", # "Halsey St & Evergreen Ave"
   "3831", # "Broadway & Hancock St"
   "3832", # "Central Ave & Weirfield St"
   "3833", # "Madison St & Evergreen Ave"
   "3836", # "Bushwick Ave & Linden St"
   "3837", # "Broadway & Kosciuszko St"
   "3863", # "Central Ave & Woodbine St"
   "3864", # "Central Ave & Covert St"
   "3866", # "Wilson Ave & Moffat St"
   "3867", # "Somers St & Broadway"
   "3868", # "Knickerbocker Ave & Halsey St"
   "3869", # "Van Buren St & Broadway"
   "3871", # "Bushwick Ave & Furman Ave"
   "3879", # "Broadway & Madison St"
   "3890", # "Grove St & Broadway"
   "3893", # "Rockaway Ave & Bainbridge St"
   "3903", # "Jefferson Ave & Evergreen Ave"
   "4117", # "Sullivan Pl & Franklin Ave"
   "4504", # "Plaza St East & Flatbush Ave"
   "4657", # "Flatbush Ave & Eastern Pkwy"
   "4658", # "Flatbush Ave & Ocean Ave"
   "4888", # "Lewis Ave & Greene Ave"
   "4889", # "Lexington Ave & Stuyvesant Ave"
   "4890", # "Stuyvesant Ave & Gates Ave"
   "4891", # "Quincy St & Malcolm X Blvd"
   "4892", # "Madison St & Malcolm X Blvd"
   "4893", # "Hancock St & Stuyvesant Ave"
   "4894", # "Macon St & Lewis Ave"
   "4896", # "Hancock St & Malcolm X Blvd"
   "4897", # "Monroe St & Patchen Ave"
   "4898", # "Putnam Ave & Ralph Ave"
   "4899", # "Jefferson Ave & Patchen Ave"
   "4900", # "Macon St & Patchen Ave"
   "4901", # "MacDonough St & Malcolm X Blvd"
   "4902", # "Patchen Ave & Bainbridge St"
   "4903", # "Halsey St & Ralph Ave"
   "4904", # "Macon St & Howard Ave"
   "4905", # "Thomas S. Boyland St & Macon St"
   "4906", # "Chauncey St & Howard Ave"
   "4907", # "Ralph Ave & Fulton St"
   "4908", # "Fulton St & Saratoga Ave"
   "4909", # "MacDougal St & Rockaway Ave"
   "4910", # "Somers St & Rockaway Ave"
   "4911", # "Thomas S. Boyland St & Fulton St"
   "4912", # "Fulton St & Williams Ave"
   "4913", # "Van Sinderen Ave & Atlantic Ave"
   "4914", # "Pacific St & Nostrand Ave"
   "4915", # "Prospect Pl & Nostrand Ave"
   "4916", # "Lincoln Pl & Nostrand Ave"
   "4917", # "Sterling Pl & New York Ave"
   "4918", # "New York Ave & St Marks Ave"
   "4919", # "Herkimer St & New York Ave"
   "4920", # "MacDonough St & Marcy Ave"
   "4922", # "Brooklyn Ave & Prospect Pl"
   "4924", # "St. Johns Pl & Kingston Ave"
   "4925", # "Albany Ave & Park Pl"
   "4926", # "Pacific St & Troy Ave"
   "4927", # "Troy Ave & Sterling Pl"
   "4929", # "Pacific St & Utica Ave"
   "4930", # "Park Pl & Buffalo Ave"
   "4931", # "Bergen St & Buffalo Ave"
   "4932", # "Columbus Pl & Atlantic Ave"
   "4933", # "St Marks Ave & Ralph Ave"
   "4934", # "Prospect Pl & Howard Ave"
   "4935", # "Sterling Pl & Ralph Ave"
   "4937", # "Pacific St & Rochester Ave"
   "4938", # "St Marks Ave & Rochester Ave"
   "4939", # "Sterling Pl & Rochester Ave"
   "4940", # "Eastern Pkwy & Ralph Ave"
   "4941", # "Bergen St & Saratoga Ave"
   "4942", # "St Marks Ave & Thomas S. Boyland St"
   "4943", # "E New York Ave & St Marks Ave"
   "4945", # "Carlton Ave & St Marks Ave"
   "4951", # "Brevoort Pl & Bedford Ave"
   "4952", # "Park Pl & Utica Ave"
   "4953", # "St Johns Pl & Utica Ave"
   "4954", # "Pacific St & Ralph Ave"
   "4955", # "St Johns Pl & Howard Ave"
   "4956", # "Dean St & Rockaway Ave"
   "4957", # "Bergen St & Mother Gaston Blvd"
   "4958", # "Pacific St & Sackman St"
   "4962", # "Monroe St & Marcus Garvey Blvd"
   "4963", # "Chauncey St & Stuyvesant Ave"
   "4964", # "Chauncey St & Malcolm X Blvd"
   "4965", # "Sumpter St & Fulton St"
   "4966", # "Thomas S. Boyland St & Marion St"
   "4967", # "Kingston Ave & Park Pl"
   "4968", # "Eastern Pkwy & Kingston Ave"
   "4969", # "Bergen St & Troy Ave"
   "4970", # "Eastern Pkwy & Troy Ave"
   "4971", # "Schenectady Ave & Prospect Pl"
   "4972", # "Buffalo Ave & St Johns Pl"
   "4973", # "Buffalo Ave & E New York Ave"
   "4978", # "Knickerbocker Ave & Moffat St"
   "4984", # "Eastern Pkwy & Rochester Ave"
   "4985", # "St Johns Pl & Saratoga Ave"
   "4989", # "Bergen St & Kingston Ave"
   "4992", # "Decatur St & Saratoga Ave"
   "4994", # "Sterling Pl & Schenectady Ave"
   "4995", # "Pacific St & Thomas S. Boyland St"
   "4997", # "Carroll St & Rochester Ave"
   "5000", # "Classon Ave & St Marks Ave"
   "5001", # "Lafayette Ave & Stuyvesant Ave"
   "5005", # "Herkimer St & Eastern Pkwy"
  ]
end

# top left Myrtle/Throop 40.69621, -73.94377
# bottom right Putnam/Broadway 40.68757, -73.91875
# stations = res['data']['stations'].select { |st| st['lat'] <= 40.69621 && st['lat'] >= 40.68757 && st['lon'] <= -73.91875 && st['lon'] >= -73.94377 }
# def old_station_ids
#   [
#     "3054",
#     "3058",
#     "3059",
#     "3836",
#     "3837",
#     "3838",
#     "3841",
#     "3842",
#     "3848",
#     "3869",
#     "3879",
#     "3890",
#     "4886",
#     "4887",
#     "4888",
#     "4889",
#     "4890",
#     "4891",
#     "4897",
#     "5001"
#   ]
# end