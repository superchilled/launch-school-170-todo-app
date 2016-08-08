require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

helpers do
  def list_complete?(list)
    (todos_count(list[:todos]) > 0) && (todos_remaining_count(list[:todos]) == 0)
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def todo_class(todo)
    'complete' if todo[:completed]
  end

  def todos_remaining_count(todos)
    todos.count { |todo| !todo[:completed] }
  end

  def todos_count(todos)
    todos.size
  end

  def display_todos_count(todos)
    "#{todos_remaining_count(todos)} / #{todos_count(todos)}"
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

# Finds the next available id to assign to a list
def next_list_id
  max = session[:lists].map { |list| list[:id] }.max || 0
  max + 1
end

# Finds the next available id to assign to a todo
def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_listname(name)
  if !(1..100).cover?(name.size)
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

def error_for_todo(name)
  if !(1..100).cover?(name.size)
    'The todo name must be between 1 and 100 characters.'
  end
end

def load_list(list_id)
  list = session[:lists].select { |list| list[:id] == list_id }.first
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect "/lists"
end

# View all the lists
get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Views a single list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = load_list(id)

  erb :edit_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_listname(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    list_id = next_list_id
    session[:lists] << {id: list_id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update and existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_listname(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# Complete alls todos on a list
post '/lists/:id/complete' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos were completed.'
  redirect "/lists/#{@list_id}"
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i

  session[:lists].reject! { |list| list[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  error = error_for_todo(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i

  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  todo = @list[:todos].select { |todo| todo[:id] == todo_id }

  todo.first[:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end
