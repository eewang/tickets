require 'open-uri'
require 'nokogiri'
require 'sqlite3'
require 'benchmark'
require 'date'
require 'gchart'
require 'launchy'
require 'erb'

db = SQLite3::Database.new("tickets_3.db")
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS events(
    id INTEGER PRIMARY KEY autoincrement,
    date_scrape text,
    team_away varchar(50),
    team_home varchar(50),
    event_date text,
    venue varchar(30),
    city varchar(20),
    state varchar(2),
    min_price real,
    tix integer
  );
SQL

# USE AUTO INCREMENT

$entries = db.execute <<-SQL
  SELECT COUNT(id) FROM events;
SQL

module Baller
  TEAMS = [
  ["ATL", "Atlanta Hawks"],
  ["BOS", "Boston Celtics"],
  ["BKN", "Brooklyn Nets"],
  ["CHA", "Charlotte Bobcats"],
  ["CHI", "Chicago Bulls"],
  ["CLE", "Cleveland Cavaliers"],
  ["DAL", "Dallas Mavericks"],
  ["DEN", "Denver Nuggets"],
  ["DET", "Detroit Pistons"],
  ["GSW", "Golden State Warriors"],
  ["HOU", "Houston Rockets"],
  ["IND", "Indiana Pacers"],
  ["LAC", "Los Angeles Clippers"],
  ["LAL", "Los Angeles Lakers"],
  ["MEM", "Memphis Grizzlies"],
  ["MIA", "Miami Heat"],
  ["MIL", "Milwaukee Bucks"],
  ["MIN", "Minnesota Timberwolves"],
  ["NOJ", "New Orleans Hornets"],
  ["NYK", "New York Knicks"],
  ["OKC", "Oklahoma City Thunder"],
  ["ORL", "Orlando Magic"],
  ["PHI", "Philadelphia 76ers"],
  ["PHO", "Phoenix Suns"],
  ["POR", "Portland Trail Blazers"],
  ["SAC", "Sacramento Kings"],
  ["SAS", "San Antonio Spurs"],
  ["TOR", "Toronto Raptors"],
  ["UTH", "Utah Jazz"],
  ["WAS", "Washington Wizards"]
  ]

COLORS = <<-EOF
Atlanta Hawks:  #01244C (navy blue)  |  #D21033 (red)
Boston Celtics:  #05854C (green)  |  #EAEFE9 (silver)  |  #FFFFFF (white)
Brooklyn Nets: #000000 (black)  |  #FFFFFF (white)
Charlotte Bobcats:  #F26532 (orange)  |  #29588B (blue)
Chicago Bulls:  #D4001F (red)  |  #000000 (black)  |  #FFFFFF (white)
Cleveland Cavaliers:  #9F1425 (red)  |  #003375 (blue)  |  #B99D6A (gold)
Dallas Mavericks:  #006AB5 (blue)  |  #F0F4F7 (silver)
Denver Nuggets:  #4393D1 (powder blue)  |  #FBB529 (gold)
Detroit Pistons:  #ED174C (red)  |  #006BB6 (blue)
Golden State Warriors:  #002942 (dark blue)  |  #E75E25 (orange)  |  #FFC33C (gold)
Houston Rockets:  #CC0000 (red)  |  #FFFFFF (white)
Indiana Pacers:  #002E62 (navy blue)  |  #FFC225 (gold)
Los Angeles Clippers:  #EE2944 (red)  |  #146AA2 (blue)  |  #FFFFFF (white)
Los Angeles Lakers:  #4A2583 (purple)  |  #F5AF1B (gold)
Memphis Grizzlies:  #001B41 (navy blue)  |  #85A2C6 (light blue)  |  #FFFFFF (white)
Miami Heat:  #B62630 (red)  |  #1E3344 (dark gray/black)  |  #FF9F00 (gold)
Milwaukee Bucks:  #00330A (hunter green)  |  #C82A39 (red)
Minnesota Timberwolves:  #015287 (blue)  |  #000000 (black)  |  #EFEFEF (silver)
New Jersey Nets:  #002258 (navy blue)  |  #D32E4C (red)  |  #EFEFF1 (silver)
New Orleans Hornets:  #0095CA (light blue)  |  #1D1060 (purple)  |  #FEBB25 (gold)  |  #FFFFFF (white)
New York Knicks:  #2E66B2 (blue)  |  #FF5C2B (orange)
Oklahoma City Thunder:  #0075C1 (light blue)  |  #E7442A (orange)  
Orlando Magic:  #077ABD (blue)  |  #C5CED5 (silver)  |  #000000 (black)
Philadelphia 76ers:  #C5003D (red)  |  #000000 (black)  |  #C7974D (gold)
Phoenix Suns:  #48286C (purple)  |  #FF7A31 (orange)  |  #FFBC1E (gold)
Portland Trail Blazers:  #000000 (black)  |  #E1393E (red)  |  #B4BDC3 (silver)
San Antonio Spurs:  #000000 (black)  |  #BEC8C9 (silver)  |  #FFFFFF (white)
Sacramento Kings:  #743389 (purple)  |  #DCE2E4 (silver)  |  #000000 (black)
Toronto Raptors:  #CD1041 (red)  |  #ECEBE9 (silver)  |  #000000 (black)
Utah Jazz:  #001D4D (navy blue)  |  #448CCE (light blue)  |  #480975 (purple)
Washington Wizards:  #004874 (blue)  |  #BC9B6A (gold)
EOF

end

class League
  include Baller
  extend Baller

  attr_accessor :name

  def self.url
    "http://www.stubhub.com/"
  end

  def self.team_names
    Baller::TEAMS.collect { |arr| arr[1]}
  end

  def self.team_abbr
    Baller::TEAMS.collect { |arr| arr[0]}
  end

  def self.team_links
    self.team_names.collect { |team| self.url + team.downcase.gsub(" ", "-") + "-tickets/" }
  end

  def self.team_name_link_array
    self.team_names.zip(self.team_links)
  end

end

class Event
  
  @@db = SQLite3::Database.new("tickets_3.db")
  @@events = []

  ATTRIBUTES = {
    :team_away => :text,
    :team_home => :text,
    :event_date => :text,
    :venue => :text,
    :city => :text,
    :state => :text,
    :min_price => :real,
    :tix => :integer,
    # :url => :text
  }

  def self.attributes
    ATTRIBUTES.keys
  end

  self.attributes.each do |attribute|
    attr_accessor attribute
  end

  def attributes_for_sql
    self.class.attributes.join(",")
  end

  def initialize( team_away, team_home, event_date, venue, city, state, min_price, tix) #, url)
    @team_away = team_away
    @team_home = team_home
    @event_date = event_date
    @venue = venue
    @city = city
    @state = state
    @min_price = min_price
    @tix = tix
    # @url = url
    @@events << [self.team_away, self.team_home, self.event_date, self.venue, self.city, self.state, self.min_price, self.tix] #, self.url]
  end

  def self.count_events
    @@events.size
  end

  def self.name_events
    @@events
  end

  def self.scrape_date
    (DateTime.now).to_s
  end

  def self.attributes_hash
    ATTRIBUTES
  end

  def self.question_marks_for_sql
    ((["?"]*self.attributes.size).join(", ")).insert(0, "?, ?, ")
  end

  def values_for_attributes_for_sql
    self.class.attributes.collect { |a| self.send(a) }
  end

  def insert_for_sql
    [values_for_attributes_for_sql].flatten
  end

  def save
    @@db.execute(
        "INSERT INTO events (id, date_scrape, #{attributes_for_sql})
        VALUES (#{self.class.question_marks_for_sql})", 
        [$entries.flatten[0] + Event.count_events, Event.scrape_date, insert_for_sql]);
  end

end

class Team
  extend Baller

  attr_accessor :name, :url

  @@color_hash = {}
  @@db = SQLite3::Database.new("tickets_3.db")

  def self.team_list
    Baller::TEAMS
  end

  def self.team_colors_list
    Array(Baller::COLORS.split("\n")).each do |item|
      @@color_hash[item.split(": ")[0].to_sym] ||= []
      @@color_hash[item.split(": ")[0].to_sym] << item.split(": ")[1].split(" ")[0].gsub("#", "")
      @@color_hash[item.split(": ")[0].to_sym] << item.split(": ")[1].split(" ")[-2].gsub("#", "")
    end
    @@color_hash
  end

  @@teams = []

  def initialize(name, url = "")
    @name = name
    @name_for_sql = @name.concat(" Tickets").to_s
    @url = url
    @away_teams = []
    @away_team_labels = []
    @@teams << [self.name, self.url]
  end

  def self.count_teams
    @@teams.size
  end

  def self.name_teams
    @@teams
  end

  def date_for_sql
    @@db.execute("SELECT event_date FROM events WHERE team_home == '#{@name_for_sql}'").flatten.collect { |date| date.split(",")[1].strip.split(" ")[0].split("/")[0..-2].join("/")}
  end

  def price_for_sql
    @@db.execute("SELECT min_price FROM events WHERE team_home == '#{@name_for_sql}'").flatten
  end

  def tix_for_sql
    @@db.execute("SELECT tix FROM events WHERE team_home == '#{@name_for_sql}'").flatten.collect do |item| 
        if item.is_a? Integer
          item / 100
        else 
          item.gsub(",", "").to_i / 100
        end
      end
  end

  def away_teams_for_sql
    @@db.execute("SELECT team_away FROM events WHERE team_home == '#{@name_for_sql}'").flatten
  end

  def x_labels(item)
    self.class.team_list.each do |combo|
      if combo[1] == item
        @away_teams << combo[0]
      end
    end
  end

  def x_labels_abbr
    away_teams_for_sql.each do |team|
      x_labels(team)
    end
    @away_teams
  end

  def away_team_x_labels_abbr
    @away_team_labels = x_labels_abbr.zip(date_for_sql).collect { |array| array.join(": ") }.join("|")
  end

  def team_color_primary
    Team.team_colors_list[@name_for_sql.split(" ")[0..-2].join(" ").to_sym][0]
  end

  def team_color_secondary
    Team.team_colors_list[@name_for_sql.split(" ")[0..-2].join(" ").to_sym][1]
  end

  def chart_filename
    @name.downcase.gsub(" ", "_").insert(0, "nba_charts/").concat(".png")
  end

  def self.search_team(team_name)
    nba_team = Team.new(team_name.split(" ").map { |word| word.capitalize }.join(" ") )
    bar_chart = Gchart.new(
                :type => 'bar',
                :size => '1000x300', 
                :encoding => 'extended',
                :bar_colors => [[nba_team.team_color_primary], [nba_team.team_color_secondary]],
                :title => nba_team.name,
                :bg => 'FAFAFA',
                :legend => ['Minimum Price (LHS)', 'Number of Tickets (RHS)'],
                :legend_position => 'bottom',
                :data => [nba_team.price_for_sql, nba_team.tix_for_sql],
                :stacked => false,
                :axis_with_labels => [['x'], ['y'], ['r']],
                :axis_labels => [["#{nba_team.away_team_x_labels_abbr}"]],
                :bar_width_and_spacing => '25',
                :axis_range => [[nil], [25], [25], nil],
                :max_value => nba_team.price_for_sql.max + 25,
                :orientation => 'v',
                :filename => "#{nba_team.chart_filename}",
                )
    bar_chart.file
    puts "Creating file... Done"
  end

end

League.team_name_link_array.each do |name, url|
  team = Team.new(name, url)
end

Team.name_teams.each do |team, url|
  begin 
    document = Nokogiri::HTML(open(url))
  rescue
    raise url.inspect
  end

  event_name = 'tbody a:first span[itemprop = "name performers"]'
  event_event_date = 'div .eventDatePadding'
  event_venue_place = 'div[itemprop = "location"] span[itemprop = "name"]'
  event_venue_city = 'div[itemprop = "address"] span[itemprop = "addressLocality"]'
  event_venue_state = 'div[itemprop = "address"] span[itemprop = "addressRegion"]'
  event_min_price = 'td[itemprop = "offers"] span[itemprop = "lowPrice"]'
  event_tix = 'td[itemprop = "offers"] span[itemprop = "offerCount"]'
  # event_url = ".eventName a"
  i = 0

  begin
    document.css(event_name).each do |title|
      event = Event.new(
        title.text.split(" at ")[0], 
        title.text.split(" at ")[1],
        document.css(event_event_date)[i].text,
        document.css(event_venue_place)[i].text,
        document.css(event_venue_city)[i].text,
        document.css(event_venue_state)[i].text,
        document.css(event_min_price)[i].text,
        document.css(event_tix)[i].text,
        # document.css(event_url)[i].text
        )
      i += 1
      event.save
    end
  rescue
  end

# end

response = ""
until response.downcase == "done"
  puts "What team do you want to search for? ('Done' to exit) "
  response = gets.chomp
  if response.downcase != "done"
    Team.search_team(response)
  else
    puts "Thanks for using my program!"
  end
end

