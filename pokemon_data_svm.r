library(tidyverse)
#install.packages('psych')
#install.packages('caTools') 
library(psych)
library(caTools)

#useful function for column names renaming.
wang.naming <- function(df) {
  
  names(df) <- tolower(names(df))
  names(df) <- gsub("_", ".", names(df))
  names(df) <- gsub(" ", ".", names(df))
  names(df) <- gsub("/", ".", names(df))
  names(df) <- gsub("-", ".", names(df))
  names(df) <- gsub(",", ".", names(df))
  #  names(df) <- gsub("..", ".", names(df))
  
  return(df)
  
}


# Splitting the dataset into the Training set and Test set 

pokemon.data <- readxl::read_xlsx(path = "Pokemon.xlsx")

#edit colnames..
names(pokemon.data) <- pokemon.data[1, ]
pokemon.data <- pokemon.data[-1, ]

pokemon.data <- wang.naming(pokemon.data)

#Remove column 1
pokemon.data$`#` <- NULL

#Dummy codess...
dummy.code.vars <- pokemon.data %>%
  dplyr::select(type.1, type.2) %>%
  colnames()

i <- 0

for(dummy in dummy.code.vars) {
  
  i <- i + 1
  temp <- psych::dummy.code(pokemon.data[[dummy]])
  temp <- as.data.frame(temp)
  
  colnames(temp) <- paste(colnames(temp), i, sep = ".")
  
  pokemon.data <- cbind(pokemon.data, temp)
  
}

rm(temp)

#We dont need type anymore since they are dummy coded...
pokemon.data <- pokemon.data %>%
  select(-type.1, -type.2)

#Recode legendary..
pokemon.data$legendary <- ifelse(pokemon.data$legendary, 1, 0)

#Legendary to factor...
pokemon.data$legendary <- as.factor(pokemon.data$legendary)

#Make name key...
pokemon.key <- pokemon.data %>%
  select(name, legendary)

#Change all NAs to 0...
pokemon.data[is.na(pokemon.data)] <- 0

#Split training set and test set baes on legendary... .75 training, .25 testing...
set.seed(123) 
split = sample.split(pokemon.data$legendary, SplitRatio = 0.83) 

training_set = subset(pokemon.data, split == TRUE) 
test_set = subset(pokemon.data, split == FALSE) 

#Remove name which is not relevant for prediction..
#test_set <- test_set %>%
#  select(-name)

#training_set <- training_set %>%
#  select(-name)

#Change types to integers.
for(c in colnames(test_set)) {
  
  if (c != "name") {
    test_set[[c]] <- as.numeric(test_set[[c]])
    training_set[[c]] <- as.numeric(training_set[[c]])
  }
  
}

rm(c)

#Fitting model parameters 1...
# Fitting SVM to the Training set 
#install.packages('e1071') 
library(e1071) 

classifier = svm(formula = legendary ~ ., 
                 data = training_set[-1], #All except the name which is not relevant...
                 type = 'C-classification', 
                 kernel = 'linear') 

predicted.1 <- predict(classifier, newdata = test_set[c(-1,-10)])

test_set$predicted_legendary <- predicted.1

param1.results <- test_set %>%
  dplyr::select(name, legendary, predicted_legendary)

table(param1.results$legendary, param1.results$predicted_legendary)

classifier = svm(formula = legendary ~ ., 
                 data = training_set[-1], #All except the name which is not relevant...
                 type = 'C-classification', 
                 kernel = 'linear',
                 cost = 0.5) 

predicted.2 <- predict(classifier, newdata = test_set[c(-1,-10)])

test_set$predicted_legendary <- predicted.2

param2.results <- test_set %>%
  dplyr::select(name, legendary, predicted_legendary)

t.pred <- table(param2.results$legendary, param2.results$predicted_legendary)
head(t.pred)
colnames(t.pred) <- c("predicted non-legendary","predicted legendary")
rownames(t.pred) <- c("actual non-legendary","actual legendary")
t.pred <- addmargins(A=t.pred, FUN = list(Total = sum), quiet = TRUE)

library(ggplot2)
ggplot(param1.results,aes(legendary))+geom_bar(aes(fill=predicted_legendary))+coord_flip()
ggplot(param2.results,aes(legendary))+geom_bar(aes(fill=predicted_legendary))+coord_flip()

accuracy <- (t.pred[1,1]+t.pred[2,2])/t.pred[3,3]
specifity <- t.pred[1,1]/t.pred[1,3]
precision <- t.pred[2,2]/t.pred[3,2]
recall <- t.pred[2,2]/t.pred[2,3]
f1 <- 2*(precision*recall)/(precision+recall)