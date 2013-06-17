-- authors: Lomtik Software (J. Winwood & John Labenski)
-- Luxinia Dev (Eike Decker & Christoph Kubisch)
---------------------------------------------------------
local ide = ide
-- Create the Search menu and attach the callback functions

local frame = ide.frame
local menuBar = frame.menuBar

local findReplace = ide.findReplace

local findMenu = wx.wxMenu{
  { ID_JUMP_TO_FUNCTION, TR("&Jump to Function")..KSC(ID_JUMP_TO_FUNCTION), TR("Jump to function") },
  { ID_JUMP_TO_FILE, TR("&Jump to File")..KSC(ID_JUMP_TO_FILE), TR("Jump to file") },
  { ID_FIND, TR("&Find")..KSC(ID_FIND), TR("Find text") },
  { ID_FINDNEXT, TR("Find &Next")..KSC(ID_FINDNEXT), TR("Find the next text occurrence") },
  { ID_FINDPREV, TR("Find &Previous")..KSC(ID_FINDPREV), TR("Find the earlier text occurence") },
  { ID_REPLACE, TR("&Replace")..KSC(ID_REPLACE), TR("Find and replace text") },
  { },
  { ID_FINDINFILES, TR("Find &In Files")..KSC(ID_FINDINFILES), TR("Find text in files") },
  { ID_REPLACEINFILES, TR("Re&place In Files")..KSC(ID_REPLACEINFILES), TR("Find and replace text in files") },
  { },
  { ID_GOTOLINE, TR("&Goto Line")..KSC(ID_GOTOLINE), TR("Go to a selected line") },
  { },
  { ID_SORT, TR("&Sort")..KSC(ID_SORT), TR("Sort selected lines") }}
menuBar:Append(findMenu, TR("&Search"))

function OnUpdateUISearchMenu(event) event:Enable(GetEditor() ~= nil) end

-- split string

local function __split(fullString, separator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
       local nFindLastIndex = string.find(fullString, separator, nFindStartIndex)
       if not nFindLastIndex then
        nSplitArray[nSplitIndex] = string.sub(fullString, nFindStartIndex, string.len(fullString))
        break
       end
       nSplitArray[nSplitIndex] = string.sub(fullString, nFindStartIndex, nFindLastIndex - 1)
       nFindStartIndex = nFindLastIndex + string.len(separator)
       nSplitIndex = nSplitIndex + 1
    end
    return nSplitArray
end

-- file search data provider

function _GenerateFileList()
  local projPath = ide.config.path.projectdir
  local files = Deployer:GetFileNamesInFolder(projPath)
  local fileArray = __split( files, "\n")
  local startIndex = string.len(projPath) + 2
  local result = {}
  for i,v in ipairs(fileArray) do
      if string.len(v)>1 then
        result[string.sub( v, startIndex)] = v
      end
  end
  return result
end

function _OnSelectFile(item)
  --DisplayOutputLn(item)
end

function _OnOpenFile(item)
  LoadFile( item, nil, true)
end

-- gloable function search data provider

function _GenGloableFuncList()
    
    local ret = Deployer:IndexFunctionDefine(ide.config.path.projectdir)
    
    local funcList =  __split( ret, "\n")
    local functionDefs = nil
    local result = {}
    
    for i,v in ipairs(funcList) do
        functionDefs = __split( v, "@")
        result[functionDefs[2]] = v
    end
    
    return result
end

function _OnJumpToFunctionDefinitionPreview(item)
    --DisplayOutputLn(item)
end

function _OnJumpToFunctionDefinition(item)
    functionDefs = __split( item, "@")
    LoadFile( functionDefs[1], nil, true)
    local l = tonumber(functionDefs[3])
    if (l and l > 0) then
      local editor = GetEditor()
      editor:GotoLine(l)
    end
end

-- search function in current document

function _GenerateFucntionList()
    local array = {}
    local editor = GetEditor()
    local lines = 0
    local linee = (editor and editor:GetLineCount() or 0)-1
    for line=lines,linee do
      local tx = editor:GetLine(line)
      local s,_,cap,l = editor.spec.isfndef(tx)
      if (s) then
        local ls = editor:PositionFromLine(line)
        local style = bit.band(editor:GetStyleAt(ls+s),31)
        if not (editor.spec.iscomment[style] or editor.spec.isstring[style]) then
          array[cap] = line
        end
      end
    end
    return array
end

function _JumpToLine(l)
    if (l and l > 0) then
      local editor = GetEditor()
      editor:GotoLine(l)
    end
end

-- muilty jump search data provider

local altJumpList = {}

function SetMuiltyAltJumpList(list)
    altJumpList = list
end

function _GenMuiltyAltJumpList()
    return altJumpList
end

-- search data provider 

local fileSearchSrouce = {
    contentsProvider = _GenerateFileList,
    callBackFunction = _OnSelectFile,
    onEnter          = _OnOpenFile
}

local gloableFunctionSearchSource = {
    contentsProvider = _GenGloableFuncList,
    callBackFunction = _OnJumpToFunctionDefinitionPreview,
    onEnter = _OnJumpToFunctionDefinition
}

local gloableAltFunctionJumpSource = {
    contentsProvider = _GenMuiltyAltJumpList,
    callBackFunction = _OnJumpToFunctionDefinitionPreview,
    onEnter = _OnJumpToFunctionDefinition
}

local functionSearchSource = {
     contentsProvider = _GenerateFunctionList,
     callBackFunction = _JumpToLine
}

-- search data provider selection

local currentSearchSrouce = fileSearchSrouce

local function GenrateContent()
  return currentSearchSrouce.contentsProvider()
end

local function OnSelectItem(item)
  return currentSearchSrouce.callBackFunction(item)
end

local function OnEnter(item)
  if currentSearchSrouce.onEnter ~= nil then
    currentSearchSrouce.onEnter(item)
  end
end

-- search window
function selectSource(source)
    if GetSearchWindow().IsShowing() and currentSearchSrouce~=source then
      GetSearchWindow().Show()
    end
    currentSearchSrouce = source
    GetSearchWindow().Show()
end

function onID_JUMP_TO_FUNCTION()
    selectSource(gloableFunctionSearchSource)
end

function onID_JUMP_TO_FILE()
    selectSource(fileSearchSrouce)
end

function ShowMuiltyAltJumpList( list )
    SetMuiltyAltJumpList(list)
    selectSource(gloableAltFunctionJumpSource)
    local mousePos = wx.wxGetMousePosition()
    GetSearchWindow()._searchWindow:Move( wx.wxPoint(mousePos.x, mousePos.y) )
end



local function q(s) return s:gsub('([%(%)%.%%%+%-%*%?%[%^%$%]])','%%%1') end

local searchWindow = nil

function HideSearchWindow()
     if searchWindow then
        searchWindow.isShown = false
        searchWindow._searchWindow:Show(searchWindow.isShown)
     end
end

function GetSearchWindow()
    --_GenerateFileList()
    if searchWindow == nil then
        searchWindow = {}
        -- gen search window UI
        searchWindow._searchWindow =
              wx.wxFrame(
                frame,
                wx.wxID_ANY,
                TR("search frame"),
                wx.wxPoint( 0, 0),
                wx.wxSize(  600, 200),
                wx.wxFRAME_NO_TASKBAR + wx.wxFRAME_FLOAT_ON_PARENT
              )
        searchWindow.edit = wx.wxTextCtrl( searchWindow._searchWindow, ID("text"), "", wx.wxPoint( 0, 0), wx.wxSize( 600, 20))
        searchWindow.grid = wx.wxGrid( searchWindow._searchWindow, ID("grid"), wx.wxPoint( 0, 20), wx.wxSize( 600, 180))

        searchWindow.array = GenrateContent()
        local count = 0 
        for k,v in pairs(searchWindow.array) do
          count = count + 1
        end

        searchWindow.grid:CreateGrid( count, 1)
        searchWindow.grid:SetRowLabelSize(0)
        searchWindow.grid:SetColLabelSize(0)
        searchWindow.grid:EnableScrolling( false, false)
        searchWindow.grid:SetColSize(0, 570)
        searchWindow.grid:SelectRow(0)

        local function UpdateList()
            searchWindow.grid:DeleteRows( 0, searchWindow.grid:GetNumberRows() )
            for k,v in pairs(searchWindow.array) do
              if string.find( string.lower(k), string.lower(q(searchWindow.edit:GetValue())) ) ~= nil then 
                searchWindow.grid:AppendRows(1)
                local rowIndex = searchWindow.grid:GetNumberRows() - 1
                searchWindow.grid:SetCellValue( rowIndex, 0, k)
                searchWindow.grid:SetReadOnly( rowIndex, 0)
                --searchWindow.grid:SetRowLabelValue(rowIndex, tostring(v+1))
              end
            end
        end

        -- event
        local function onTextChange()
            UpdateList()
            if searchWindow.grid:GetNumberRows()>0 then
              searchWindow.grid:SelectRow(0)
              searchWindow.grid:SetGridCursor( 0, 0)
              searchWindow.selectedRow = 0
              OnSelectItem(searchWindow.array[searchWindow.grid:GetCellValue(searchWindow.selectedRow,0)])
            end
        end

        searchWindow.edit:Connect( wx.wxEVT_COMMAND_TEXT_UPDATED, onTextChange)
        searchWindow.selectedRow = 0
        function onKeyDown(event)
                
                local keycode = event:GetKeyCode()
                
                if keycode == wx.WXK_F3 then
                    onID_JUMP_TO_FUNCTION()
                    return
                elseif keycode == wx.WXK_F4 then
                    onID_JUMP_TO_FILE()
                    return
                elseif keycode == wx.WXK_ESCAPE then
                    searchWindow.isShown = false
                    searchWindow._searchWindow:Show(searchWindow.isShown)
                    return
                elseif keycode == wx.WXK_RETURN then
                    searchWindow.isShown = false
                    searchWindow._searchWindow:Show(searchWindow.isShown)
                    OnEnter(searchWindow.array[searchWindow.grid:GetCellValue(searchWindow.selectedRow,0)])
                    return
                end

                if keycode ~= wx.WXK_UP and keycode ~= wx.WXK_DOWN then
                    event:Skip()
                    return
                end
                
                if keycode == wx.WXK_UP then
                  searchWindow.selectedRow = searchWindow.selectedRow - 1
                  searchWindow.grid:MoveCursorUp(false)
                end
                
                if keycode == wx.WXK_DOWN then
                  searchWindow.selectedRow = searchWindow.selectedRow + 1
                  searchWindow.grid:MoveCursorDown(false)
                end

                if searchWindow.selectedRow <  0 then 
                  searchWindow.selectedRow = 0
                end

                if searchWindow.selectedRow >= searchWindow.grid:GetNumberRows() then
                  searchWindow.selectedRow = searchWindow.selectedRow - 1
                end

                if searchWindow.selectedRow ~= -1 then
                    searchWindow.grid:SelectRow(searchWindow.selectedRow)
                    OnSelectItem(searchWindow.array[searchWindow.grid:GetCellValue(searchWindow.selectedRow,0)])
                end

        end
        searchWindow.edit:Connect(wx.wxEVT_KEY_DOWN, onKeyDown)
        
        function onLostFocus(event)
          --DisplayOutputLn(" set onLostFocus called !")
        end
        searchWindow.edit:Connect( wx.wxEVT_COMMAND_KILL_FOCUS, onLostFocus)
        
        local function OnGetFocus(event)
            searchWindow.grid:SelectRow( event:GetRow() )
            OnEnter(searchWindow.array[ searchWindow.grid:GetCellValue( event:GetRow() ,0)])
            searchWindow.edit:SetFocus()
            searchWindow.isShown = false
            searchWindow._searchWindow:Show(searchWindow.isShown)
        end
        searchWindow.grid:Connect(wx.wxEVT_GRID_CELL_LEFT_CLICK, OnGetFocus)
        
        searchWindow.isShown = false

        local function show()
          if not searchWindow.isShown then
              searchWindow.array = GenrateContent()
              searchWindow.isShown = true
              searchWindow.selectedRow = -1
              searchWindow.edit:ChangeValue("")
              UpdateList()
          else
              searchWindow.isShown = false
          end
          searchWindow._searchWindow:Show(searchWindow.isShown)
          if searchWindow.isShown then
              searchWindow.edit:SetFocus()
          end 
        end

        searchWindow.Show = show
        
        local function isShowing()
          return searchWindow.isShown
        end
        
        searchWindow.IsShowing = isShowing
  end
  
  local x,y = frame:GetPosition():GetXY()
  searchWindow._searchWindow:Move( wx.wxPoint(x+460, y+102))
  return searchWindow
end

frame:Connect( ID_JUMP_TO_FUNCTION, wx.wxEVT_COMMAND_MENU_SELECTED, 
  function()
    if GetSearchWindow().IsShowing() and currentSearchSrouce~=gloableFunctionSearchSource then
      GetSearchWindow().Show()
    end
    currentSearchSrouce = gloableFunctionSearchSource
    GetSearchWindow().Show()
  end)
frame:Connect(ID_JUMP_TO_FUNCTION, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)

frame:Connect(ID_JUMP_TO_FILE, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    if GetSearchWindow().IsShowing() and currentSearchSrouce~=fileSearchSrouce then
      GetSearchWindow().Show()
    end
    currentSearchSrouce = fileSearchSrouce
    GetSearchWindow().Show()
  end)
frame:Connect(ID_JUMP_TO_FILE, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)

frame:Connect(ID_FIND, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    findReplace:Show(false)
  end)
frame:Connect(ID_FIND, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)

frame:Connect(ID_REPLACE, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    findReplace:Show(true)
  end)
frame:Connect(ID_REPLACE, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)

frame:Connect(ID_FINDINFILES, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    findReplace:Show(false,true)
  end)
frame:Connect(ID_REPLACEINFILES, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    findReplace:Show(true,true)
  end)

frame:Connect(ID_FINDNEXT, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    local editor = GetEditor()
    if editor and ide.wxver >= "2.9.5" and editor:GetSelections() > 1 then
      local selection = editor:GetMainSelection() + 1
      if selection >= editor:GetSelections() then selection = 0 end
      editor:SetMainSelection(selection)
      editor:EnsureCaretVisible()
    else
      findReplace:GetSelectedString()
      findReplace:FindString()
    end
  end)
frame:Connect(ID_FINDNEXT, wx.wxEVT_UPDATE_UI,
  function (event) event:Enable(findReplace:GetSelectedString() or findReplace:HasText()) end)

frame:Connect(ID_FINDPREV, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    local editor = GetEditor()
    if editor and ide.wxver >= "2.9.5" and editor:GetSelections() > 1 then
      local selection = editor:GetMainSelection() - 1
      if selection < 0 then selection = editor:GetSelections() - 1 end
      editor:SetMainSelection(selection)
      editor:EnsureCaretVisible()
    else
      findReplace:GetSelectedString()
      findReplace:FindString(true)
    end
  end)
frame:Connect(ID_FINDPREV, wx.wxEVT_UPDATE_UI,
  function (event) event:Enable(findReplace:GetSelectedString() or findReplace:HasText()) end)

-------------------- Find replace end

frame:Connect(ID_GOTOLINE, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    local editor = GetEditor()
    local linecur = editor:LineFromPosition(editor:GetCurrentPos())
    local linemax = editor:LineFromPosition(editor:GetLength()) + 1
    local linenum = wx.wxGetNumberFromUser(TR("Enter line number"),
      "1 .. "..tostring(linemax),
      TR("Goto Line"),
      linecur, 1, linemax,
      frame)
    if linenum > 0 then
      editor:GotoLine(linenum-1)
    end
  end)
frame:Connect(ID_GOTOLINE, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)

frame:Connect(ID_SORT, wx.wxEVT_COMMAND_MENU_SELECTED,
  function (event)
    local editor = GetEditor()
    local buf = {}
    for line in string.gmatch(editor:GetSelectedText()..'\n', "(.-)\r?\n") do
      table.insert(buf, line)
    end
    if #buf > 0 then
      table.sort(buf)
      editor:ReplaceSelection(table.concat(buf,"\n"))
    end
  end)
frame:Connect(ID_SORT, wx.wxEVT_UPDATE_UI, OnUpdateUISearchMenu)
