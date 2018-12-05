--
-- print vehicleTypes to file
--
--
-- @author:    	Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- @history:	v1.0 - 2018-12-05 - Farming Simulator 19 
--

TYPE_COUNTED 	= 1;
TYPE_PARENT		= 2;
TYPE_FOUND 		= 3;

REPLACE_FIND	= 1;
REPLACE_NEW		= 2;


function getParentVehicle(_table)
	local isParent = {};
	
	for _type, _vehicle in pairs(_table) do
		for vehicleType, vehicle in pairs(g_vehicleTypeManager.vehicleTypes) do
			if _type ~= vehicleType then
				local totalSpecs = #_vehicle.specializationNames;
				local countedSpecs = 0;
				
				-- if we can match all specializations from vehicle then its an parent of that type
				
				for _, name in ipairs(_vehicle.specializationNames) do
					if vehicle.specializationsByName[name] ~= nil then
						countedSpecs = countedSpecs + 1;
					end;
				end;
				
				if countedSpecs == totalSpecs then
					-- fuelTrailer 	is parent of X
					-- baseFillable is parent of fuelTrailer
					-- base 		is parent of baseFillable
					-- print(_type .. " is parent of " .. vehicleType);
					
					if isParent[vehicleType] == nil then
						isParent[vehicleType] = {countedSpecs, _type, {}};
					else
						if isParent[vehicleType][TYPE_COUNTED] < countedSpecs then
							isParent[vehicleType][TYPE_COUNTED] = countedSpecs;
							isParent[vehicleType][TYPE_PARENT] = _type;
							isParent[vehicleType][TYPE_FOUND] = {};	-- Empty as we got an new highest number
							
						elseif isParent[vehicleType][TYPE_COUNTED] == countedSpecs then
							isParent[vehicleType][TYPE_FOUND][_type] = "Found " .. countedSpecs .. " specializations";
						end;
					end;
				end;
			end;
		end;
	end;
	
	isParent["locomotive"] = nil; -- This matched with crane.. hoping this arent intended.
	
	for _type, v in pairs(isParent) do
		-- Make sure we dont mix these, logical?
		local words = {"trailer", "implement"};
		
		for _, word in pairs(words) do
			local w = string.find(_type:lower(), word);
			
			if w ~= nil then
				local missmatch = "trailer";
				
				if word == "trailer" then
					missmatch = "implement";
				end;
				
				if string.find(v[TYPE_PARENT]:lower(), missmatch) ~= nil then
					for _foundType in pairs(v[TYPE_FOUND]) do
						if string.find(_foundType:lower(), missmatch) ~= nil then
							print("Removing " .. _foundType .. " from " .. _type);
							
							v[TYPE_FOUND][_foundType] = nil; -- Dont mix implement and trailer
						else
							print(_type .. " 	changed parent to " .. _foundType .. " 	from " .. v[TYPE_PARENT]);
							
							v[TYPE_PARENT] = _foundType;
							v[TYPE_FOUND][_foundType] = nil; -- Clean up debug
						end;
					end;
				end;
			end;
		end;
		
		-- teleHandler -- tractorCrabSteering - This looks wrong, needs deeper look
		-- baseFillable - fillableImplement
		
		local replace = {
			{"base", "base"},					-- Make sure to use the base... spec before something else	
			{"tractor", "baseDrivable"},		-- Replace tractor with baseDrivable, both have the same specs.
			{"spreader", "sprayer"}				-- Basing this on how it was setup in FS17 
		};
		
		for _, t in pairs(replace) do
			if string.find(_type:lower(), t[REPLACE_FIND]) == nil then
				for _foundType in pairs(v[TYPE_FOUND]) do
					if string.find(_foundType:lower(), t[REPLACE_NEW]) ~= nil then
						print(_type .. " 	changed parent to " .. _foundType .. " 	from " .. v[TYPE_PARENT]);
						
						v[TYPE_PARENT] = _foundType;
						v[TYPE_FOUND][_foundType] = nil;
					end;
				end;
			end;
		end;
		
		-- Force an update to these, I could be wrong here but Im assuming these at least use the base as parent and not the random stuff we had
		local replace = {
			{"baseTipper", "base"},
			{"baseFillable", "base"},
			{"baseAttachable", "base"},
			{"baseDrivable", "base"}
		};
		
		for _, t in pairs(replace) do
			if _type == t[REPLACE_FIND] then
				v[TYPE_PARENT] = t[REPLACE_NEW];
			end;
		end;
		
		-- clean up for debug
		local i = 0;
		for _foundType in pairs(v[TYPE_FOUND]) do
			i = i + 1;
		end;
		
		if i == 0 then
			v[TYPE_FOUND] = nil;
		end;
	end;
	
	for _type, _vehicle in pairs(_table) do
		if isParent[_type] == nil then
			print("Is root " .. _type);
		end;
	end;
	
	return isParent;
end;

function getParentpecializations(_name)
	if _name ~= nil then
		return g_vehicleTypeManager.vehicleTypes[_name[TYPE_PARENT]].specializationsByName;
	end;
	
	return nil;
end;

function printVehicleTypesToFile(_parent)
	local xmlFile = createXMLFile("savingVehicleTypes", Utils.getFilename("printedVehicleTypes.xml",  getUserProfileAppPath()), "VehicleTypes");
	local i = 0;
	
	for _type, vehicle in pairs(g_vehicleTypeManager.vehicleTypes) do
		local key = string.format("VehicleTypes.type(%d)", i);
		
		setXMLString(xmlFile, key .. "#name", _type);
		
		if _parent[_type] ~= nil then
			setXMLString(xmlFile, key .. "#parent", _parent[_type][TYPE_PARENT]);
		else
			setXMLString(xmlFile, key .. "#className", vehicle.className);
			setXMLString(xmlFile, key .. "#filename", vehicle.filename:gsub("dataS", "$dataS"));
		end;
		
		local blacklist = getParentpecializations(_parent[_type]);
		local subI = 0;
		for _, specializationName in ipairs(vehicle.specializationNames) do
			local subKey = string.format(key .. ".specialization(%d)", subI);
			
			if (blacklist ~= nil and blacklist[specializationName] == nil or blacklist == nil) then
				setXMLString(xmlFile, subKey .. "#name", specializationName);
				
				subI = subI + 1;
			end;
		end;
		
		i = i + 1;
	end;
	
	saveXMLFile(xmlFile);
	delete(xmlFile);
end;

local rootVehicleTypes = getParentVehicle(g_vehicleTypeManager.vehicleTypes);

-- DebugUtil.printTableRecursively(rootVehicleTypes, " ", 0, Utils.getNoNil(depth, 3));

printVehicleTypesToFile(rootVehicleTypes);