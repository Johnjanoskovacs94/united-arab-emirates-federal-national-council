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
  Capybara::Poltergeist::Driver.new(app, js_errors: false, timeout: 60)
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
  option_count = browser.find_all('.search-box select option').size - 1
  1.upto(option_count) do |option_index|
    option = browser.find_all('.search-box select option')[option_index]
    id = option.value
    name = option.text
    option.select_option
    wait_for_name(name)
    scrape_person(browser.html, id, url)
    option_index += 1
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
