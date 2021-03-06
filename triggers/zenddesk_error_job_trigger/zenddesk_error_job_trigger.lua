-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function post_create_error_ticket(p)
	if(p == nil) then
		return {
			ref = "post_create_error_ticket",
			name = "Post Create Error Ticket",
			description = "Creates a support ticket on Zendesk if job fails",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"FAILED"},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== TRIGGER CREATE ERROR TICKET =========")
	local customerUUID = p.input:getCustomerUUID()
	local priorityKey = getPriorityKey(customerUUID)
	local priorityKeyValue = "normal"
	if(priorityKey.success) then
		priorityKeyValue = priorityKey.keyValue
	end
	local zendeskToken = checkBeKey(p.customer:getBillingEntityUUID(),"ZENDESK_API_TOKEN")
	local zendeskEmail = checkBeKey(p.customer:getBillingEntityUUID(),"ZENDESK_LOGIN_EMAIL")
	if(zendeskToken.success)then
		local apiDomain = checkBeKey(p.customer:getBillingEntityUUID(),"ZENDESK_DOMAIN_NAME")
		if(apiDomain.success)then
			local url = "https://".. apiDomain.keyValue ..".zendesk.com/api/v2/tickets.json"

			local ticketBody = ""
			ticketBody = ticketBody .. "Error happened on Job:" .. p.input:getJobType():toString() .. "\nJob UUID:" .. p.input:getResourceUUID() .. "\nJob Item ID:" .. p.input:getItemUUID()
			local input = { ticket = { subject = p.input:getItemDescription(), comment = {body = ticketBody}, type = "problem"}, priority = priorityKeyValue}
			local js = new ("JSON")
			local params = js:encode(input)

			print('Sending Job log to Zendesk.')

			local loginDetails = {
				username = zendeskEmail.keyValue .. "/token",
				password = zendeskToken.keyValue
			}

			generate_http_request(loginDetails,params,url)
		else
			print('ZENDESK_DOMAIN_NAME key not found!')
		end
	else
		print('ZENDESK_API_TOKEN key not found!')
	end
	print("======== TRIGGER CREATE ERROR TICKET COMPLETE =========")

	return { exitState = "SUCCESS" }
end

function getPriorityKey(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({"ZENDESK_PRIORITY_KEY"})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local billingEntity = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))
	if(billingEntity:getList():size() == 1) then
		for i = 0, billingEntity:getList():get(0):getResourceKey():size() - 1, 1 do
			if(billingEntity:getList():get(0):getResourceKey():get(i):getName() == "ZENDESK_PRIORITY_KEY") then
				return {success = true, keyValue = billingEntity:getList():get(0):getResourceKey():get(i):getValue() }
			end
		end
	else
		return {success = false}
	end
end

function checkBeKey(beUUID, resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({beUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local billingEntity = adminAPI:listResources(searchFilter,nil,new("ResourceType","BILLING_ENTITY"))
	if(billingEntity:getList():size() == 1) then
		for i = 0, billingEntity:getList():get(0):getResourceKey():size() - 1, 1 do
			if(billingEntity:getList():get(0):getResourceKey():get(i):getName() == resourceKeyName) then
				return {success = true, keyValue = billingEntity:getList():get(0):getResourceKey():get(i):getValue() }
			end
		end
	else
		return {success = false}
	end
end

function generate_http_request(token,params,url)
	local headers = {}
	headers['Content-Type'] = "application/json"

	local simplehttp = new("simplehttp")
	local httpconn = simplehttp:newConnection({url=url})
	httpconn:setRequestHeaders(headers)

	if(type(token) == "table") then
		httpconn:setBasicAuth(token.username,token.password)
	else
		httpconn:setBasicAuth(token,'')
	end

	local returnString = ""
	local httpcode = ""
	if (httpconn:post(params,
			function (val)
				returnString = returnString .. val
				return true
			end)
	) then

	else
		local error , message = httpconn:getLastError()
		print('HTTPError: ' .. error)
		print('HTTPErrorMessage: ' .. message)
	end

	httpconn:disconnect()

	local js = new ("JSON")
	local jsonReturnString = js:decode(returnString)
end

function register()
	return {"post_create_error_ticket"}
end
