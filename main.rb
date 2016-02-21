# LIBRARY FOR MAKING GITHUB API CALLS EASIER
require 'octokit'
# PRETTY PRINT OUTPUT IN TABLE
require 'terminal-table'


def take_input
    puts "Please enter the github repo url"
    gets.chomp
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
    def initialize
        @octokit_client = Octokit::Client.new
        @repo_url = take_input
        @total_open_issues = 0
        @issues_opened_in_last_24_hours = 0
        @issues_opened_between_7days_24hours = 0
        @issues_opened_before_7days = 0
        @page_size = 100
    end

    def store_results
        open_issues,num_pages,last_page_count = fetch_issues
        @total_open_issues = calc_total_open_issue_count num_pages,last_page_count
        issues_opened_in_last_7days = open_issues.select {|issue| issue.created_at >= 7.days.ago }.count
        @issues_opened_before_7days = @total_open_issues - issues_opened_in_last_7days 
        @issues_opened_in_last_24_hours = open_issues.select {|issue| issue.created_at >= 1.days.ago}.count
        @issues_opened_between_7days_24hours = issues_opened_in_last_7days -  @issues_opened_in_last_24_hours 
    end


    def print_output
        #puts "#{@total_open_issues} #{@issues_opened_in_last_24_hours} #{@issues_opened_between_7days_24hours} #{@issues_opened_before_7days}" 
        rows = []
        rows << ['Total number of open issues',@total_open_issues]
        rows << ['Number of open issues that were opened in the last 24 hours',@issues_opened_in_last_24_hours ]
        rows << ['Number of open issues that were opened more than 24 hours ago but less than 7 days ago',@issues_opened_between_7days_24hours] 
        rows << ['Number of open issues that were opened more than 7 days ago',@issues_opened_before_7days ]
        puts Terminal::Table.new :rows => rows
    end

    private

    def calc_total_open_issue_count num_pages,last_page_count
        (num_pages-1)*@page_size + last_page_count
    end

    def fetch_issues
        open_issues_arr = []
        number_of_pages = 0
        last_page_count = 0
        loop do 
            # First request for issues and the private method below will check for execeptions as well.
            open_issues_arr = make_request 'issues',{:per_page=>@page_size,:state=>'open'}
            last_response = @octokit_client.last_response
            # Fetching the last pages number from the last page url which is provided via github API pagination feature
            number_of_pages = last_response.rels[:last].href.match(/&page=(\d+).*$/)[1]
            if number_of_pages == 1 || open_issues_arr.count % @page_size != 0 || open_issues_arr.last.created_at <= 7.days.ago 
                last_page_count = last_response.rels[:last].get.data.size unless number_of_pages == 1
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
            puts "Repo not found"
            exit
        rescue Octokit::InvalidRepository
            puts "Invalid Repository Name"
            exit
        end
            
    end
end
#PROGRAM EXECUTION STARTS FROM HERE
rep = RepoStat.new
rep.store_results
rep.print_output
