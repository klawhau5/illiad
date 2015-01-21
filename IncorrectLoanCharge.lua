--At point of Borrowing Loan receipt,
--displays popup if BBH has been incorrectly
--charged.


local interfaceMngr = nil
local form = {}
form.Form = nil
form.Browser = nil

local inRapid = false
local inAffiliations = false
local usr = GetSetting("username")
local pwd = GetSetting("password")
local rapidUsr = GetSetting("rapidUsr")
local rapidPwd = GetSetting("rapidPwd")
local instID = 0

function Init()
	if GetFieldValue("Transaction", "UserName") ~= "Lending" and
		GetFieldValue("Transaction", "RequestType") == "Loan" then
		interfaceMngr = GetInterfaceManager()
		
		--initialize browser for OCLC dir.
		form.Form = interfaceMngr:CreateForm("IncorrectLoanCharge", "Script")
		form.Browser = form.Form:CreateBrowser("IncorrectLoanCharge", "Browser", "IncorrectLoanCharge")
		form.Browser.WebBrowser.ScriptErrorsSuppressed = true
		form.Form:Show()

		CheckRapidGroup()
	end
end

function OCLCLogIn()
	form.Browser:SetFormValue("signInForm", "authorization", usr)
	form.Browser:SetFormValue("signInForm", "password", pwd)
	form.Browser:SubmitForm("signInForm")
end

function NavigateSearch()
	form.Browser:Navigate("https://illpolicies.oclc.org/dill-ui/Search.do?")
end

function OCLCLoggedIn()
	local testUrl = "https://illpolicies.oclc.org/dill-ui/SignIn.do?"
	local currentUrl = form.Browser.WebBrowser.Url:ToString()
	if testUrl ~= currentUrl then
		return true
	else
		return false
	end
end

function OnSearchPage()
	local testUrl = "https://illpolicies.oclc.org/dill-ui/Search.do?"
	local currentUrl = form.Browser.WebBrowser.Url:ToString()
	if testUrl == currentUrl then
		return true
	else
		return false
	end
end

function SymbolSearch()
	local myForm = form.Browser:GetForm(nil, "searchForm")
	local libraryName = GetFieldValue("Transaction", "LendingLibrary")
	form.Browser:SetFormValue(myForm, "searchTerm", libraryName)
	myForm:InvokeMember("submit")
	form.Browser:RegisterPageHandler("custom", "ResultsLoaded", "GetAffiliates", false)
end

function ResultsLoaded()
	local testUrl = "https://illpolicies.oclc.org/dill-ui/Search.do?"
	if form.Browser.WebBrowser.Url:ToString() ~= testUrl then
		instID = form.Browser.WebBrowser.Url:ToString()
		instID = string.match(instID, '=.+')
		return true
	else
		return false
	end
end

function GetAffiliates()
	form.Browser:RegisterPageHandler("custom", "ProfileLoaded", "Alert", false)
	form.Browser:Navigate("https://illpolicies.oclc.org/dill-ui/ProfileView.do?institutionId" .. instID)
end

function ProfileLoaded()
	local testUrl = "https://illpolicies.oclc.org/dill-ui/ProfileView.do?institutionId" .. instID
	if form.Browser.WebBrowser.Url:ToString() == testUrl then
		return true
	else
		return false
	end
end

function Alert()
	--Test to see what IFMCost fieldvalue is
	-- SetFieldValue("Transaction", "Location", GetFieldValue("Transaction", "IFMCost"))
	--OCLC PD html
	--SetFieldValue("Transaction", "Location", "hej")
	local html = form.Browser.WebBrowser.DocumentText 
	if string.match(html, "LIBRARIES VERY") == "LIBRARIES VERY" or 
		string.match(html, "LYRA") == "LYRA" or 
		string.match(html, "SO6 GAC/UL") == "SO6 GAC/UL" or
 		string.match(html, "NELINET") == "NELINET" or
		string.match(html, "OBERLIN") == "OBERLIN" or
		string.match(html, "IDS PROJECT") == "IDS PROJECT" or
		inRapid == true then
		if GetFieldValue("Transaction", "IFMCost") ~= "$0.00" and
			GetFieldValue("Transaction", "IFMCost") ~= '' and 
			GetFieldValue("Transaction", "IFMCost") ~= nil then
			interfaceMngr:ShowMessage("Discrepancy with 'Billing Category' or Group Affiliations.", "Review Lending Charges")
		end
	end
	if string.match(html, "LIBRARIES VERY") == nil and 
		string.match(html, "LYRA") == nil and 
		string.match(html, "SO6 GAC/UL") == nil and
 		string.match(html, "NELINET") == nil and
		string.match(html, "OBERLIN") == nil and
		string.match(html, "IDS PROJECT") == nil and
		inRapid == false and
		(GetFieldValue("Transaction", "IFMCost") == "$0.00" or
		GetFieldValue("Transaction", "IFMCost") == '' or
		GetFieldValue("Transaction", "IFMCost") == nil) then
		interfaceMngr:ShowMessage("Discrepancy with 'Billing Category' or Group Affiliations.", "Review Lending Charges")
	end
end

function CheckRapidGroup()
	form.Browser:RegisterPageHandler("formExists", "aspnetForm", "RapidLogIn", false)
	form.Browser:Navigate("http://rapidill.org/Default.aspx")
	form.Browser:RegisterPageHandler("custom", "RapidLoggedIn", "NavRapidGroups", false)
end

function RapidLogIn()
	form.Browser:SetFormValue("aspnetForm", "ctl00_MainContentPlaceHolder_LoginControl1_txtUsername", rapidUsr)
	form.Browser:SetFormValue("aspnetForm", "ctl00_MainContentPlaceHolder_LoginControl1_txtPassword", rapidPwd)
	form.Browser:ClickObject("ctl00_MainContentPlaceHolder_LoginControl1_btnLogin")
end

function RapidLoggedIn()
	local testUrl = "http://rapidill.org/Ill/MainMenu"
	if form.Browser.WebBrowser.Url:ToString() == testUrl then
		return true
	else
		return false
	end
end

function NavRapidGroups()
	form.Browser:Navigate("http://rapidill.org/Ill/ReciprocalList")
	form.Browser:RegisterPageHandler("custom", "IsRapidGroups", "CheckGroups", false)
end

function IsRapidGroups()
	local testUrl = "http://rapidill.org/Ill/ReciprocalList"
	if form.Browser.WebBrowser.Url:ToString() == "http://rapidill.org/Ill/ReciprocalList" then
		return true
	else
		return false
	end
end

function CheckGroups()
	local html = form.Browser.WebBrowser.DocumentText
	local myOCLCSymbol = GetFieldValue("Transaction", "LendingLibrary")
	html = string.match(html, [[BBHReciprocalPartners.+AcademicM]])
	if string.match(html, myOCLCSymbol) == myOCLCSymbol then
		inRapid = true
	end
	CheckOCLC()
end

function CheckOCLC()
	form.Browser:RegisterPageHandler("formExists", "signInForm", "OCLCLogIn", false)
	form.Browser:Navigate("https://illpolicies.oclc.org/dill-ui/SignIn.do?")
	form.Browser:RegisterPageHandler("custom", "OCLCLoggedIn", "NavigateSearch", false)
	form.Browser:RegisterPageHandler("custom", "OnSearchPage", "SymbolSearch", false)
end