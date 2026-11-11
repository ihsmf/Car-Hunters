local Store = {}

Store.State = nil
Store.Money = 0
Store.Income = 0
Store.CollectionValue = 0
Store.Changed = Instance.new("BindableEvent")
Store.MoneyChanged = Instance.new("BindableEvent")

function Store.Set(state)
	Store.State = state
	Store.Money = state.money
	Store.Income = state.income or 0
	Store.CollectionValue = state.collectionValue or 0
	Store.Changed:Fire()
end

function Store.SetMoney(money, income, value)
	Store.Money = money
	Store.Income = income
	Store.CollectionValue = value or Store.CollectionValue
	if Store.State then
		Store.State.money = money
		Store.State.income = income
	end
	Store.MoneyChanged:Fire()
end

function Store.Banked(partId)
	return Store.State and Store.State.parts[partId] or 0
end

function Store.Carried(partId)
	return Store.State and Store.State.carried[partId] or 0
end

function Store.CarriedTotal()
	local n = 0
	if Store.State then
		for _, v in pairs(Store.State.carried) do
			n = n + v
		end
	end
	return n
end

function Store.BankedTotal()
	local n = 0
	if Store.State then
		for _, v in pairs(Store.State.parts) do
			n = n + v
		end
	end
	return n
end

return Store
