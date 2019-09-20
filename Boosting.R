#setwd("/Users/sijia/Downloads")

#load all the libraries first
library(randomForest)
library(dplyr)
library(xgboost)
library(data.table)
library(mltools)
library(stringr)
library(DiagrammeR)


#load the aggregated dataset with last permanent price
df <-read.csv("updated_part1.csv")

# Feature Engineering function
spfy2 <- function(df){
  df$Date<- as.Date(df$Date)
  df$Image.Count<-as.numeric(levels(df$Image.Count))[df$Image.Count]
  df$Review.Count<-as.numeric(levels(df$Review.Count))[df$Review.Count]
  df$Average.Rating<-as.numeric(levels(df$Average.Rating))[df$Average.Rating]
  df$Image.Count[is.na(df$Image.Count)]<-0
  df$Review.Count[is.na(df$Review.Count)]<-0
  df$Average.Rating[is.na(df$Average.Rating)]<-0
  response<-df$Orders/df$Visits
  df$Conversion <- response
  df <- category_median_CR(df)
  df <- add_last_conversion_rate(df)
  
  features<-setdiff(names(df),c("OMSID","VENDORNAME","class","TYPE","BRAND_ADVOCATE_STATUS","BEGIN_DATE","END_DATE","PROMO_NAME","PROMO_TYPE"))
  train<- select(df,features)
  vendors <- data.table(as.factor(df$VENDORNAME))
  vendors <- sparsify(vendors)
  vendors <-as.matrix(vendors)
  vendors <- as.data.frame(vendors)
  nas <- which(is.na(df$PROMO_TYPE))
  ptype <- data.table(df$PROMO_TYPE)
  ptype[nas] <- "None"
  ptype <- sparsify(ptype)
  ptype <-as.matrix(ptype)
  ptype <- as.data.frame(ptype)
  cl <- data.table(as.factor(df$class))
  cl[is.na(cl)]<-0
  cl <- sparsify(cl)
  cl<-as.matrix(cl)
  cl<-as.data.frame(cl)
  tp <- data.table(as.factor(df$TYPE))
  tp[is.na(tp)]<-0
  tp <- sparsify(tp)
  tp <-as.matrix(tp)
  tp <- as.data.frame(tp)
  brand <- data.table(as.factor(df$BRAND_ADVOCATE_STATUS))
  brand[is.na(brand)]<-0
  brand <- sparsify(brand)
  brand <-as.matrix(brand)
  brand <- as.data.frame(brand)
  vendors$X <-df$X
  cl$X <-df$X
  tp$X <-df$X
  brand$X <-df$X
  ptype$X <-df$X
  f1<-merge(train,vendors,"X","X")
  f2<-merge(f1,cl,"X","X")
  f2<-merge(f2,tp,"X","X")
  f2<-merge(f2,brand,"X","X")
  f2<-merge(f2,ptype,"X","X")
  features<-setdiff(names(f2),c("X"))
  train<- select(f2,features)
  train$Date<- as.numeric(train$Date)
  
  return(train)
}

# Calculate the median conversion rate for each class
category_median_CR <- function(df) {
  summary_table <- df %>%
    group_by(class) %>%
    summarise(
      CR_median = median(Orders/Visits),
      CR_mean = mean(Orders/Visits)
    )
  summary_table <- inner_join(df,summary_table, by=c("class"))
  return(summary_table)
}

# Include the previous conversion rate as an additional predictor
add_last_conversion_rate <- function(mat) {
  mat$X3 <- c(0L, mat$OMSID[-1]  == mat$OMSID[-nrow(mat)]) 
  mat$X2 <- lag(mat$Conversion)
  mat$hist_conversion_rate <- ifelse(mat$X3 == 0 | is.na(mat$X2), max(mat$CR_median,mat$CR_mean),mat$X2)
  mat <- mat[,! names(mat) %in% c("X2","X3")]
  return(mat)
}


# xgBoosting function, which calls the feature engineering function
# The inputs are the dataset and the regression type(in our case, we choose to do logistic regression)
boosting <- function(df,reg){
  a <- spfy2(df)
  set <- setdiff(colnames(a),"Conversion")
  mat <- a[,set]
  resp <- a$Conversion
  # delete last price, orders, visits
  mat <- mat[,! names(mat) %in% c("Orders","Visits","lastPrice")]
  #accepts a dataframe, takes a slice of the data, and creates and xgboost model on it
  type = str_c("reg:",toString(reg))
  boost <- xgboost(data = as.matrix(mat), label = as.numeric(resp),nrounds = 200, early_stopping_rounds = 50, objective = type,eval_metric="rmse",silent=TRUE)
  return(boost)
}

# delete rows if the corresponding conversive is >1
df$Conversion <- df$Orders/df$Visits
df <- df[which(df$Conversion<=1),]
df <- df[,! names(df) %in% c("Conversion")]



# Call the boosting function to get the model
# Use the first 400000 rows as training data for the model
xagglog<-boosting(df[1:400000,],"logistic")
#save the model as "xgboost_logistic.model" and will be used later in the UI
xgb.save(xagglog, "xgboost_logistic.model")



#get the test error from the remaining data
a <- spfy2(df[400001:nrow(df),])
set <- setdiff(colnames(a),"Conversion")
mat <- a[,set]
resp <- a$Conversion
# delete last price, orders, visits
mat <- mat[,! names(mat) %in% c("Orders","Visits","lastPrice")]
predagglog1 <-predict(xagglog,as.matrix(mat))
# calculate the error rate
rmse <- mean((predagglog1-resp)^2)
