name "get_execution_id"
rs_ca_ver 20131202
short_description "This is not an empty string"

operation "launch" do
  description "Do the stuff"
  definition "launch"
end

#include:../definitions/sys.cat.rb

#include:../definitions/tags.cat.rb

define launch() do
  call get_execution_id() retrieve $execution_id
  call log("The execution ID is "+$execution_id,"None")
end
