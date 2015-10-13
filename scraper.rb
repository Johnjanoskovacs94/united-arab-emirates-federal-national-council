require 'scraperwiki'
require 'capybara'
require 'capybara/poltergeist'
require 'nokogiri'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, js_errors: false, timeout: 60, debug: true)
end

def browser
  @browser ||= Capybara::Session.new(:poltergeist)
end

def wait_for_name(name)
  loop do
    puts "Waiting for #{name}"
    table = browser.find_all('.article-box table')[1]
    break if table && table.text.include?(name)
    sleep 1
  end
end

def scrape_list(url)
  browser.visit(url)
  options = browser.find_all('.search-box select option').drop(1).map { |o| [o.value, o.text] }

  if options.length == 0
    puts browser.html
    abort "Failed to find list of people"
  end

  puts "Found #{options.length} people"
  options.each do |option|
    id, name = option
    puts "Scraping #{name}"
    browser.select(name, from: 'ctl00_main_g_214c5390_2e7d_43ff_a733_fb5b642fb7be_ctl00_ddlMember')
    wait_for_name(name)
    scrape_person(browser.html, id, url)
  end
end

def scrape_person(html, id, source_url)
  noko = Nokogiri::HTML(html)
  table = noko.css('.article-box table')[1]
  name_ar = table.xpath('.//tr[2]/td[2]').text.tidy
  name_en = table.xpath('.//tr[2]/td[3]').text.tidy
  person = {
    id: id,
    name__en: name_en,
    name__ar: name_ar,
    name: name_en || name_ar,
    email: table.xpath('.//tr[3]/td[2]').text.tidy,
    photo: table.xpath('.//tr[4]/td[2]/img')[0]['src'],
    birth_place: table.xpath('.//tr[5]/td[2]').text.tidy,
    source: source_url
  }
  puts name_en
  ScraperWiki.save_sqlite([:id], person)
end

term = {
  id: 2011,
  name: '2011–2015',
  start_date: '2011',
  end_date: '2015'
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_list('https://www.almajles.gov.ae/MembersProfiles/Pages/MemProfile.aspx')
