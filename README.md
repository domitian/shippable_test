## Prerequisites for installing app:
1. Ruby version 2.2
2. bundler gem
3. Sinatra(A lightweight web app built using this framework)

## Run the App:
Ways to start the app.

1. `ruby main.rb`
2. Open your browser and listen at `localhost:4567`

## Solution:
1. Input is taken via text field on the html page.
2. Using github API V3.

#### Assumptions:-
1. Open issues means issues which are opened as well the open pull requests. This is because github API assumes open pull requests as issues as well.
2. github repo url entered is random.

#### What I did:-
I am using a library name `octokit.rb` for making calls to the github api. 
When the input url is given, an api request is made to github's `issues` api for listing issues with filters `:per_page=> 100,:state=> 'open'`.
Since github API paginates by default, we get list of issues sorted by `created_at` date in desc order in page 1 and stored in `open_issues_arr`. The headers of this response also contains links for `last page`. So two conditions arise here.
  1. If the last page link is empty, then the page fetched is the final page.
  2. If last page link is not empty, we get the last page number using a regex.

And we fetch the final page if first page is not final and get the count of issues in final page.
So we calculate the total number of issues using this formula below.
```ruby
(number_of_pages-1)*page_size + final_page_issues_count
```

Now we check if last issue in `open_issues_arr` whose `created_at` is greater than 7 days, if it is we fetch the next page and push the issues to `open_issues_arr`. We repeat the same process till we find `created_at` of last issue in `open_issues_arr` `created_at` is less than 7 days or the last issue is the final issue.

Now we have the issues in `open_issues_arr`, we use a filter to find the issues which are opened is last 24 hours. and we use another filter to find issues which are opened in last 7 days.

We use both the results and subtract them to get the issues opened more than 24 hours but less than 7 days ago.
For issues open before 7 days, we subtract issues opened in 7 days from total number of issues. 

We store all this data and print it in a tabular format. For printing the output in table format 'terminal-table' library/gem is used.


## Optimized Solution given more time:-

#### Assumption:-
 If request github repo is random, this could be the best solution:-

#### What to do:-
We can use a database to store the past request data for a specific github repo url along with the request time for that url.
1. If the current request time of the url is less than 1 day for the request for url in database, We fetch first page and last page if there and see if total issue is changed and also check if any new requests were opened in the last 24 hours, if there were none, then we don't have to make any additional requests and show the past data. Ofcourse this is under the assumption that the closed issues can't be reopened.
2. We can do a similar thing if the request time for the url is less than 7 days.

#### Assumption:-
 If request github repo is from fixed set of repos.

#### What to do:-
 We can use database for this as well, but since it is for fixed set we first fetch the total issues and request time initially and store them in database.
 1. Then we use github's `event API for issues` and we periodically make requests to this API and make changes in database as necassary by the response.
