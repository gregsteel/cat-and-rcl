require 'rubygems'
require 'bundler/setup'

require 'rake'
require 'json'
require 'yaml'
require 'logger'
require 'rest-client'


################################################################################
# BEGIN: Helpers
#
#
################################################################################

# Validates that the specified file exists, raising an error if it does not.
# Then reads the file into a string which is returned
#
# @param file [String] the path to the file which should be returned as a string
#
# @return [String] the content of the supplied file
def file_to_str_and_validate(file)
  cat_str = File.open(File.expand_path(file), 'r') { |f| f.read }
end

# Gets options from ~/.right_api_client/login.yml
#
# @return [Hash] The options in ~/.right_api_client/login.yml converted to a hash
def get_options
  options = YAML.load_file(
    File.expand_path("#{ENV['HOME']}/.right_api_client/login.yml")
  )
end

def get_list_of_includes(file)
  dedupe_include_list = {}
  contents = file_to_str_and_validate(file)
  contents.scan(/#include:(.*)$/).each do |include|
    include_filepath = File.expand_path(include.first, File.dirname(file))
    dedupe_include_list.merge!({include_filepath => include.first})
    # This merges only the new keys by doing a diff
    child_includes_hash = get_list_of_includes(include_filepath)
    new_keys = child_includes_hash.keys() - dedupe_include_list.keys()
    merge_these = child_includes_hash.select {|k,v| new_keys.include?(k) }
    dedupe_include_list.merge!(merge_these)
  end
  dedupe_include_list
end

def preprocess_template(file)
  parent_template = file_to_str_and_validate(file)
  dedup_include_list = get_list_of_includes(file)

  dedup_include_list.each do |key,val|
    include_filepath = key
    include_contents = <<EOF
###############################################################################
# BEGIN Include from #{val}
###############################################################################
EOF

    include_contents += file_to_str_and_validate(key)

    include_contents += <<EOF
###############################################################################
# END Include from #{val}
###############################################################################
EOF

    parent_template.sub!("#include:#{val}",include_contents)
  end
  # Clear all include lines from templates which were included from other templates
  parent_template.gsub!(/#include:(.*)$/,"")
  parent_template
end

def template_create(template_filepath,cookies)
  options = get_options()
  create_req = RestClient::Request.new(
    :method => :post,
    :url => "#{options[:selfservice_url]}/api/designer/collections/#{options[:account_id]}/templates",
    :payload => {
      :multipart => true,
      :source => File.new(template_filepath, "rb")
    },
    :cookies => cookies,
    :headers => {"X_API_VERSION" => "1.0"}
  )
  create_req.execute
end

def template_update(template_id,template_filepath,cookies)
  options = get_options()
  update_req = RestClient::Request.new(
    :method => :put,
    :url => "#{options[:selfservice_url]}/api/designer/collections/#{options[:account_id]}/templates/#{template_id}",
    :payload => {
      :multipart => true,
      :source => File.new(template_filepath, "rb")
    },
    :cookies => cookies,
    :headers => {"X_API_VERSION" => "1.0"}
  )
  update_req.execute
end

def template_upsert(template_filepath,cookies)
  template_href = ""
  options = get_options()
  template = preprocess_template(template_filepath)
  matches = template.match(/^name\s*"(?<name>.*)"/)
  name = matches["name"]

  templates = get_templates(cookies)
  existing_templates = templates.select{|template| template["name"] == name }

  tmpfile = Tempfile.new([name,".cat.rb"])
  begin
    tmpfile.write(template)
    tmpfile.close()
    if existing_templates.length != 0
      template_id = existing_templates.first()["id"]
      response = template_update(template_id,tmpfile.path,cookies)
      template_href = "/api/designer/collections/#{options[:account_id]}/templates/#{template_id}"
    else
      response = template_create(tmpfile.path,cookies)
      template_href = response.headers[:location]
    end
  ensure
    tmpfile.close!()
  end
  template_href
end

################################################################################
# END: Helpers
#
#
################################################################################

################################################################################
# BEGIN: SS API
#
#
################################################################################
def get_cookies
  options = get_options()
  cookies = nil

  if options.include?(:email) && options.include?(:password)
    puts "Logging into RightScale API 1.5 @ #{options[:api_url]}"
    cm_login_req = RestClient::Request.new(
      :method => :post,
      :payload => URI.encode_www_form({
        :email => options[:email],
        :password => options[:password],
        :account_href => "/api/accounts/#{options[:account_id]}"
      }),
      :url => "#{options[:api_url]}/api/session",
      :headers => {"X_API_VERSION" => "1.5"}
    )
    cm_login_resp = cm_login_req.execute

    puts "Logging into self service @ #{options[:selfservice_url]}"
    ss_login_req = RestClient::Request.new(
      :method => :get,
      :url => "#{options[:selfservice_url]}/api/catalog/new_session?account_id=#{options[:account_id]}",
      :cookies => {"rs_gbl" => cm_login_resp.cookies["rs_gbl"]}
    )
    ss_login_resp = ss_login_req.execute
    cookies = cm_login_resp.cookies
  end

  if options.include?(["access_token"])
    # OAuth
    raise "Oops, sorry, haven't implemented oAuth yet!"
  end

  if options.include?(["instance_token"])
    raise "Sorry, don't think we can authenticate with SS using an instance token"
  end

  cookies
end

def compile_template(cookies, template_source)
  options = get_options()
  begin
    puts "Uploading template to SS compile_template"
    compile_req = RestClient::Request.new(
      :method => :post,
      :url => "#{options[:selfservice_url]}/api/designer/collections/#{options[:account_id]}/templates/actions/compile",
      :payload => URI.encode_www_form({
        "source" => template_source
      }),
      :cookies => cookies,
      :headers => {"X_API_VERSION" => "1.0"}
    )
    #RestClient.log = Logger.new(STDOUT)
    compile_req.execute
    puts "Template compiled successfully"
  rescue RestClient::ExceptionWithResponse => e
    puts "Failed to compile template"
    errors = JSON.parse(e.http_body)
    puts JSON.pretty_generate(errors).gsub('\n',"\n")
  end
end

def get_templates(cookies)
  options = get_options()
  list_req = RestClient::Request.new(
    :method => :get,
    :url => "#{options[:selfservice_url]}/api/designer/collections/#{options[:account_id]}/templates",
    :cookies => cookies,
    :headers => {"X_API_VERSION" => "1.0"}
  )
  response = list_req.execute
  JSON.parse(response.body)
end

################################################################################
# END: SS API
#
#
################################################################################

################################################################################
# BEGIN: Tasks
#
#
################################################################################

desc "Compile a template to discover any syntax errors"
task :template_compile, [:filepath] do |t,args|
  cat_str = preprocess_template(args[:filepath])

  cookies = get_cookies()
  compile_template(cookies, cat_str)
end

desc "Preprocess a template, replacing include:/path/to/file statements with file contents, and produce an output file.  Default output filepath is \"processed-\"+:input_filepath"
task :template_preprocess, [:input_filepath,:output_filepath] do |t,args|
  input_filedir = File.dirname(File.expand_path(args[:input_filepath]))
  input_filename = File.basename(args[:input_filepath])
  args.with_defaults(:output_filepath => File.join(input_filedir, "processed-#{input_filename}"))
  output_filepath = File.expand_path(args[:output_filepath])
  processed_template = preprocess_template(args[:input_filepath])
  File.open(File.expand_path(output_filepath), 'w') {|f| f.write(processed_template)}

  puts "Created a processed file at #{output_filepath}"
end

desc "Upload a new template or update an existing one (based on name)"
task :template_upsert, [:filepath] do |t,args|
  cookies = get_cookies()
  href = template_upsert(args[:filepath],cookies)
  puts "Template upserted. HREF: #{href}"
end

desc "List templates"
task :templates_list do |t,args|
  cookies = get_cookies()
  templates = get_templates(cookies)
  puts JSON.pretty_generate(templates)
end

################################################################################
# END: Tasks
#
#
################################################################################
