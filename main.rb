# LIBRARY FOR MAKING GITHUB API CALLS EASIER
require 'octokit'
# Minimal web interface
require 'sinatra'
require 'uri'

# creating exception to be catched in heroku app
class InternalError < StandardError
end

#def take_input
#    puts "Please enter the github repo url"
#    gets.chomp
#end

def parse_input_uri url
    begin
        uri = URI.parse url
        uri.host ? uri.path[1..-1] : uri.path
    rescue Exception => exec
        puts "Invalid URL"
    end
end
# Util functions added to core module needed later for calculating time diff
class Fixnum
  SECONDS_IN_DAY = 24 * 60 * 60

  def days
    self * SECONDS_IN_DAY
  end

  def ago
    Time.now - self
  end
end

# Class request maker and fetcher and storage in object
class RepoStat
    def initialize input_url
        @octokit_client = Octokit::Client.new
        @repo_url = parse_input_uri(input_url)
        @total_open_issues = 0
        @issues_opened_in_last_24_hours = 0
        @issues_opened_between_7days_24hours = 0
        @issues_opened_before_7days = 0
        @page_size = 100
    end

    def fetch_results
        open_issues,num_pages,last_page_count = fetch_issues_arr
        @total_open_issues = calc_total_open_issue_count num_pages,last_page_count
        issues_opened_in_last_7days = open_issues.select {|issue| issue.created_at >= 7.days.ago }.count
        @issues_opened_before_7days = @total_open_issues - issues_opened_in_last_7days 
        @issues_opened_in_last_24_hours = open_issues.select {|issue| issue.created_at >= 1.days.ago}.count
        @issues_opened_between_7days_24hours = issues_opened_in_last_7days -  @issues_opened_in_last_24_hours 
        [@total_open_issues,@issues_opened_in_last_24_hours,@issues_opened_between_7days_24hours,@issues_opened_before_7days]
    end



    private

    def calc_total_open_issue_count num_pages,last_page_count
        (num_pages-1)*@page_size + last_page_count
    end

    def fetch_issues_arr
        open_issues_arr = []
        number_of_pages = 0
        last_page_count = 0
        loop do 
            # First request for issues and the private method below will check for execeptions as well.
            open_issues_arr = make_request 'issues',{:per_page=>@page_size,:state=>'open'}
            last_response = @octokit_client.last_response
            # Fetching the last pages number from the last page url which is provided via github API pagination feature
            number_of_pages = last_response.rels[:last] ? last_response.rels[:last].href.match(/&page=(\d+).*$/)[1] : 1
            if number_of_pages == 1 || open_issues_arr.count % @page_size != 0 || open_issues_arr.last.created_at <= 7.days.ago 
                last_page_count = (number_of_pages == 1)? open_issues_arr.count : last_response.rels[:last].get.data.size 
                break
            end
            open_issues_arr += last_response.rels[:next].get.data
        end
        [open_issues_arr,number_of_pages.to_i,last_page_count.to_i]
    end

    def make_request request_type,options = {}
        begin
            @octokit_client.send(request_type,@repo_url,options)
        rescue Octokit::NotFound 
            raise InternalError.new, "Repo not found"
        rescue Octokit::InvalidRepository
            raise InternalError.new, "Invalid Repository Name, Maybe you forgot to put http or https in the url"
        end
            
    end
end
#PROGRAM EXECUTION STARTS FROM HERE
#rep = RepoStat.new
#rep.store_results
#rep.print_output
get '/' do
    begin
        if params[:input_url]
            rep = RepoStat.new(params[:input_url])
            @output_arr = rep.fetch_results
        end

    rescue InternalError => exec
        @error_msg = exec.message
    rescue Faraday::ConnectionFailed => exec
        @error_msg = "Internet Issue on our servers, please bear with us"
    rescue Exception => exec
        @error_msg = "#{exec.message}, please report this error to bobba.surendra@gmail.com"
    end
    erb :index
end
