import csv, time, random
from sklearn.neighbors import LocalOutlierFactor
from sklearn.metrics import mean_squared_error

RESULTS = []

def load_dataset(file):
    instances = []
    targets = []
    training_dict = {}
    
    with open(file) as csvfile:
        csvreader = csv.reader(csvfile)
        for tokens in csvreader:
            row = []
            for x in range(0, len(tokens)):
                try:
                    if x == 2:
                        row.append(tokens[x])
                    else:
                        row.append(float(tokens[x]))
                except:
                    if x not in training_dict:
                        training_dict[x] = {}
                    if tokens[x] not in training_dict[x]:
                        training_dict[x][tokens[x]] = len(training_dict[x])
                    row.append(training_dict[x][tokens[x]])
            
            # only include 1% of actual injected processes
            if row[-1] == 0.0 or random.randint(0, 99) < 1:
                instances.append(row[:-1])
                targets.append(row[-1])
    return [instances, targets]


def check_accuracy(targets, scores, threshold, instances):
    fal_pos = 0
    fal_neg = 0
    tru_pos = 0
    tru_neg = 0
    
    guesses = []
    
    for x in range(0, len(targets)):
        lt_threshold = scores[x] < threshold
        
        if lt_threshold and targets[x] == 1:
            tru_pos += 1
            guesses.append(1)
        if lt_threshold and targets[x] == 0:
            fal_pos += 1
            guesses.append(1)
        if not lt_threshold and targets[x] == 1:
            fal_neg += 1
            guesses.append(0)
        if not lt_threshold and targets[x] == 0:
            tru_neg += 1
            guesses.append(0)
    
    # calculate the precision and accuracy
    # precision = TP / (TP + FP)
    if tru_pos + fal_pos > 0:
        precision = float(tru_pos) / (float(tru_pos) + float(fal_pos))
    else:
        precision = "0/0"
    if (float(fal_pos) + float(fal_neg) + float(tru_pos) + float(tru_neg)) > 0:
        accuracy = (float(tru_pos) + float(tru_neg)) / (float(fal_pos) + float(fal_neg) + float(tru_pos) + float(tru_neg))
    else:
        precision = "0/0"
    recall = float(tru_pos) / (float(tru_pos) + float(fal_neg))
    rmse = mean_squared_error(guesses, targets)
    
    print("False Positive: ", end="")
    print(fal_pos)
    print("False Negative: ", end="")
    print(fal_neg)
    print("True Positive: ", end="")
    print(tru_pos)
    print("True Negative: ", end="")
    print(tru_neg)
    print("Precision: ", end="")
    print(precision)
    print("Accuracy: ", end="")
    print(accuracy)
    print("Recall: ", end="")
    print(recall)
    print("RMSE:", end="")
    print(rmse)
    
    r = {}
    r["FP"] = fal_pos
    r["FN"] = fal_neg
    r["TP"] = tru_pos
    r["TN"] = tru_neg
    r["precision"] = precision
    r["accuracy"] = accuracy
    r["recall"] = recall
    r["rmse"] = rmse
    return r

def run_test():
    global RESULTS
    dataset = load_dataset("master_dataset_v6.csv")

    training = []
    # only select certain fields
    for p in dataset[0]:
        instance = []
        instance.append(p[1])
        instance.append(p[18])
        instance.append(p[-1])
        instance.append(p[-5])
        instance.append(p[-6])
        current = p[2].split(",")
        training.append(instance)

    lof = LocalOutlierFactor(n_neighbors=3)
    bools = lof.fit_predict(training)
    scores = lof.negative_outlier_factor_
    targets = []

    for x in range(0, len(scores)):
        targets.append(dataset[1][x])

    r = check_accuracy(targets, scores, -1, dataset[0])
    
    RESULTS.append(r)
    
    # get an average so far
    avg_precision = 0
    avg_accuracy = 0
    avg_recall = 0
    avg_rmse = 0
    
    for r in RESULTS:
        avg_precision += r["precision"]
        avg_accuracy += r["accuracy"]
        avg_recall += r["recall"]
        avg_rmse += r["rmse"]
    
    print("Average Precision: ", end="")
    print(avg_precision / len(RESULTS))
    print("Average Accuracy: ", end="")
    print(avg_accuracy / len(RESULTS))
    print("Average Recall: ", end="")
    print(avg_recall / len(RESULTS))
    print("Average RMSE: ", end="")
    print(avg_rmse / len(RESULTS))

# perform 1000 tests, average the results as we go
for x in range(0, 25):
    print("Iteration "+str(x))
    run_test()
    print("-----------------------------------")





