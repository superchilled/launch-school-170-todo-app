require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
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
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]

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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Update and existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

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
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = 'All todos were completed.'
  redirect "/lists/#{@list_id}"
end

# Delete a todo list
post '/lists/:id/destroy' do
  id = params[:id].to_i

  session[:lists].delete_at(id)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@list_id}"
end

# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'

  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end
