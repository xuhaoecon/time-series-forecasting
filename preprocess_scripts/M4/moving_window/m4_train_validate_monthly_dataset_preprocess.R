output_dir = "./datasets/text_data/M4/moving_window/"
suppressWarnings(dir.create(output_dir, recursive=TRUE)) # create the output directory if not existing
input_file = "./datasets/text_data/M4/Monthly-train.csv"

m4_dataset <- readLines(input_file)
m4_dataset <- strsplit(m4_dataset, ',')

max_forecast_horizon = 18
seasonality_period = 12

unlink(paste(output_dir, "m4_stl_monthly_*", sep=""))

for (validation in c(TRUE, FALSE)) {
    for (idr in 2 : length(m4_dataset)) {
        if (idr - 1 <= 10016 && idr - 1 >= 1) { #Macro Series
            input_size = 15
            output_path = paste(output_dir, "m4_stl_monthly_macro_", sep = '/')
        }
        else if (idr - 1 <= 20991 && idr - 1 > 10016) {
            input_size = 15
            output_path = paste(output_dir, "m4_stl_monthly_micro_", sep = '/')
        }
        else if (idr - 1 <= 26719 && idr - 1 > 20991) {
            input_size = 15
            output_path = paste(output_dir, "m4_stl_monthly_demo_", sep = '/')
        }
        else if (idr - 1 <= 36736 && idr - 1 > 26719) {
            input_size = 15
            output_path = paste(output_dir, "m4_stl_monthly_industry_", sep = '/')
        }
        else if (idr - 1 <= 47723 && idr - 1 > 36736) {
            input_size = 15
            output_path = paste(output_dir, "m4_stl_monthly_finance_", sep = '/')
        }
        else if (idr - 1 > 47723) {
            input_size = 5
            output_path = paste(output_dir, "m4_stl_monthly_other_", sep = '/')
        }
        output_path = paste(output_path, max_forecast_horizon, sep = '')
        output_path = paste(output_path, 'i', input_size, sep = '')
        if (validation) {
            output_path = paste(output_path, 'v', sep = '')
        }
        output_path = paste(output_path, 'txt', sep = '.')

        time_series = unlist(m4_dataset[idr], use.names = FALSE)
        time_series_log = log(as.numeric(time_series[2 : length(time_series)]))
        time_series_length = length(time_series_log)


        if (! validation) {
            time_series_length = time_series_length - max_forecast_horizon
            time_series_log = time_series_log[1 : time_series_length]
        }
        # apply stl
        stl_result = tryCatch({
            sstl = stl(ts(time_series_log, frequency = seasonality_period), "period")
            seasonal_vect = as.numeric(sstl$time.series[, 1])
            levels_vect = as.numeric(sstl$time.series[, 2])
            values_vect = as.numeric(sstl$time.series[, 2] + sstl$time.series[, 3])# this is what we are going to work on: sum of the smooth trend and the random component (the seasonality removed)
            cbind(seasonal_vect, levels_vect, values_vect)
        }, error = function(e) {
            seasonal_vect = rep(0, time_series_length)#stl() may fail, and then we would go on with the seasonality vector=0
            levels_vect = time_series_log
            values_vect = time_series_log
            cbind(seasonal_vect, levels_vect, values_vect)
        })

        input_windows = embed(stl_result[1 : (time_series_length - max_forecast_horizon), 3], input_size)[, input_size : 1]
        output_windows = embed(stl_result[- (1 : input_size) , 3], max_forecast_horizon)[, max_forecast_horizon : 1]
        level_values = stl_result[input_size : (time_series_length - max_forecast_horizon), 2]
        input_windows = input_windows - level_values
        output_windows = output_windows - level_values
        if (validation) {
            # create the seasonality metadata
            seasonality_windows = embed(stl_result[- (1 : input_size) , 1], max_forecast_horizon)[, max_forecast_horizon : 1]
            sav_df = matrix(NA, ncol = (4 + input_size + max_forecast_horizon * 2), nrow = length(level_values))
            sav_df = as.data.frame(sav_df)
            sav_df[, (input_size + max_forecast_horizon + 3)] = '|#'
            sav_df[, (input_size + max_forecast_horizon + 4)] = level_values
            sav_df[, (input_size + max_forecast_horizon + 5) : ncol(sav_df)] = seasonality_windows
        }else {
            sav_df = matrix(NA, ncol = (2 + input_size + max_forecast_horizon), nrow = length(level_values))
            sav_df = as.data.frame(sav_df)
        }

        sav_df[, 1] = paste(idr - 1, '|i', sep = '')
        sav_df[, 2 : (input_size + 1)] = input_windows

        sav_df[, (input_size + 2)] = '|o'
        sav_df[, (input_size + 3) : (input_size + max_forecast_horizon + 2)] = output_windows

        write.table(sav_df, file = output_path, row.names = F, col.names = F, sep = " ", quote = F, append = TRUE)
    }
}