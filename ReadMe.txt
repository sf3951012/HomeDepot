Readme


Aggregation (3 files)
1. First step: merge.Rmd
In this file, we merged the visits/orders, enrichment, price and brand datasets from department 21,22,23 as an example because we have limited computer capacity.

If there is enough capacity, all datasets should be merged together and outputted as a super-large dataset with all brand/vendor information, enrichment details, visit/order information and price information of products over time.

2. Second step: aggregate.Rmd
Using a nested for loop, for each product, aggregate the rows if there is no change in enrichment nor price information (so summing up its visit numbers and its orders numbers)

3. Third Step: lastPermPrice.Rmd
Add an additional last permanent price variable in order to obtain a consistent discount information. 



Modelling (1 file)
Boosting.R
Includes 2 main functions
- spfy2() to do feature engineering
- boosting(data, regression type) to call spfy2() first and then do xgboost ()
So split the dataset into training and testing datasets and create the model using boosting(). Then get the test errors based on the predicting results using test errors. 



User Interface (2 main files)

1. helper.R
Loads the model we got from the modelling part, as well as other 2 files "table_NumRows.csv" which records the average number of rows of each product for each class and "table_CR.csv" which includes the median and mean conversion rate of each class.

- calc_conversion()
  To calculate the conversion rate given all the user input. Return a value between 0 and 1.
- determine_brand()
  To determine the product's brand and return a matrix with entries of 0/1 value. 
  For example, a product is "3-M", then the value will be 1 and the entry of the matrix will be 1 too.
- determine_class()
  To determine a product's department, class and subclass and return a matrix with entries of 0/1 value. The entry with value 1 means that the product has the same "department_class_subclass".9
- determine_promoType()
  To determine a product's promotional type and return a matrix with entries of 0/1 value.
- determine_priceType()
  To determine a product's price type (either permanent or promotional price) and then return a matrix with entries of 0/1 value.

2. app.R
Use Shiny.app to build the UI
- shinyUI() which designs the appearance of the UI.
- shinyServer() which gives the functionality of the inputs. So it includes functions to calculate discount amount, discount percent off, and the conversion rate in percentage with a 95% confidence interval. 

