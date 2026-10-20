class_name Country
extends RefCounted
## A country definition plus its campaign state. Province ownership is not
## stored here; ask WorldState for owned provinces.

# Static definition
var id: String
var name: String
var adjective: String
var color: Color

# Campaign state
var government_type: String = ""
var capital_province_id: int = 0
var treasury: float = 0.0
## Loans: [amount, annual interest rate, day number taken].
var loans: Array = []
## Money owed: the sum of the loans.
var debt: float:
	get:
		var total := 0.0
		for l: Array in loans:
			total += l[0]
		return total
## Government policies: tax rate per estate in percent (Estates.ROLES order,
## up to Estates.TAX_MAX), and spending in percent (Policies.RANGES): court,
## minting, fort, army and navy maintenance.
var tax_rates: Array = Estates.customary_rates()
var spending: Dictionary = Policies.defaults()
## Colonial policy (index into Colonisation.POLICIES), and the scenario's
## (what an older save without one gets).
var colonial_policy := 0
## A colonial nation's colonial region ("" for every other country).
var colonial_region := ""
var start_colonial_policy := 0

## Price inflation in percent: raises every cost.
var inflation := 0.0
## How content each estate is (0-100, Estates.ROLES order).
var satisfaction: Array = [50.0, 50.0, 50.0, 50.0, 50.0]
## No lender will deal with us before this day number (after a bankruptcy).
var bankrupt_until := -1
## Day number of the last bankruptcy (lenders remember: dearer credit).
var last_bankruptcy := -1
## Last month's money movements, [source, amount] (income +, expense -);
## every change to the treasury is in here under a name.
var ledger: Array = []
var legitimacy: float = 50.0
var stability: int = 0
