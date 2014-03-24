require 'rubygems'
require 'scraperwiki'
require 'httparty'
require 'open-uri'
require 'json'
require 'i18n'

# --------------------
# scrapable_classes.rb
# --------------------

module RestfulApiMethods

  def format info
    info
  end

  def put record
  end

  def post record
  end
end

class PeopleStorage
  include RestfulApiMethods

  def save record
    post record
  end

  def post record
    #######################
    # for use with morph.io
    #######################

    if ((ScraperWiki.select("* from data where `uid`='#{record['uid']}'").empty?) rescue true)
      # Convert the array record['organizations'] to a string (by converting to json)
      if record['organizations'].is_a? Array
        record['organizations'] = JSON.dump(record['organizations'])
      end
      ScraperWiki.save_sqlite(['uid'], record)
      puts "Adds new record " + record['uid']
    else
      puts "Skipping already saved record " + record['uid']
    end
  end
end

class CongressmenProfiles < PeopleStorage
  def initialize()
    super()
    @location = 'http://pmocl.popit.mysociety.org/api/v0.1/persons/?per_page=200'
    @location_organizations = 'http://pmocl.popit.mysociety.org/api/v0.1/organizations/'
  end

  def process
    response = HTTParty.get(@location, :content_type => :json)
    response = JSON.parse(response.body)
    popit_congressmen = response['result']

    popit_congressmen.each do |congressman|
      record = get_info congressman
      post record
    end
  end

  def get_info congressman
    organizations = String.new
    if !congressman['memberships'].empty?
      congressman_organization_id = congressman['memberships'].first['organization_id']
      organizations = get_memberships congressman_organization_id
    end
    record = {
      'uid' => congressman['id'],
      'name' => I18n.transliterate(congressman['name']),
      'chamber' => congressman['title'],
      'district' => I18n.transliterate(congressman['represent'].first['district']),
      'commune' => I18n.transliterate(congressman['represent'].first['comunas']),
      'region' => I18n.transliterate(congressman['represent'].first['region']),
      'profile_image' => '',
      'organization_id' => '',
      'organizations' => organizations,
      'date_scraped' => Date.today.to_s
    }
    if !congressman['images'].nil? then record['profile_image'] = congressman['images'].first['url'] end
    if !organizations.empty? then record['organization_id'] = congressman_organization_id end
    return record
  end

  def get_memberships organization_id
    response = HTTParty.get(@location_organizations + organization_id, :content_type => :json)
    response = JSON.parse(response.body)
    popit_membership = response['result']

    organizations = Array.new
    organizations[0] = I18n.transliterate(popit_membership['name'])
    i = 1
    popit_membership['other_names'].each do |organization|
      organizations[i] = I18n.transliterate(organization['name'])
      i = i + 1
    end
    return organizations
  end
end


# ---------------------
# congressmen_runner.rb
# ---------------------

if !(defined? Test::Unit::TestCase)
  CongressmenProfiles.new.process
end
