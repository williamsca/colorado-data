# Colorado-Data
This repository contains the source code and data for a longitudinal study of local government finances in Colorado. The scripts use Amazon's Textract service to extract data on property assessments and mill levies from PDF files. The data is then cleaned and exported as a .csv file for public use.

## TODO:
- [X] manually identify the key tables from the [Annual Reports](https://drive.google.com/drive/folders/1L2hUG8ds64Wkud307-KZ89aOdJpkFgeN) and extract them. Look for "County Valuation by Classification" and all tables in Section X.

## Methodology
Consider the identity

$$Revenue_{ct} = AssessedValuation_{ct} * TaxRate_{ct}$$

where $c$ is the county and $t$ is the year. We can decompose the assessed valuation into a weighted average of the residential and non-residential assessed valuations:

$$AssessedValuation_{ct} = [\theta_{ct} * RAR_t + (1-\theta_{ct}) * NRAR_t] * Valuation_{ct}$$

where $\theta_{ct}$ is residential property as a share of total property value in the county, $RAR_t$ is the residential assessment rate, and $NRAR_t$ is the non-residential assessment rate. I construct an instrument $G_{ct}$ as

$$G_{ct} \equiv [\theta_{c,1980} * RAR_t + (1-\theta_{c,1980}) * NRAR_t]$$

where I fix the residential share of total property value at its 1980 level to avoid any endogenous response of residential shares $\theta_{ct}$ to statewide changes in $RAR_t$. Substitute into the first equation and take logs to obtain the first-stage equation

$$\log(Revenue_{ct}) = \log(G_{ct}) + \log(Valuation_{ct}) + \log(TaxRate_{ct}) + \epsilon_{ct}$$

The error term $\epsilon_{ct}$ captures differences between the instrument $G$ and the actual effective assessment ratio due to differences between $\theta_{ct}$ and $\theta_{c,1980}$.

> rev <- feols(
+     revenue_ln ~ gallagher_ln + tax_rate_ln | county + year,
+     data = dt
+ )
NOTE: 1 observation removed because of NA values (LHS: 1).
> etable(rev, digits = 3)
                             rev
Dependent Var.:       revenue_ln
                                
gallagher_ln    -1.02*** (0.244)
tax_rate_ln       0.179. (0.095)
Fixed-Effects:  ----------------
county                       Yes
year                         Yes
_______________ ________________
S.E.: Clustered       by: county
Observations               1,007
R2                       0.99007
Within R2                0.13772
---
Signif. codes: 0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

How should I interpret the negative coefficient on the $G$ variable ($gallagher\_ln$)? It has the opposite sign of what I expected to see.

