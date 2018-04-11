# II Brazilian School on Prosody
#
# Book chapter on Praat tutorial
#
# Time-normalization of fundamental frequency contours: a hands-on tutorial
#
# created: 2014-02-03
# modified: 2014-04-02

# Load required libraries
library(ggplot2)
library(reshape2)
library(dplyr)

# Load required libraries
library(ggplot2)
library(dplyr)
library(reshape2)

# Load data file
tnf0 <- read.delim("case_study/case-study.txt")
tbl_df(tnf0)

# Query the data frame: levels of some ID variables
levels(tnf0$word)
levels(tnf0$stress)
levels(factor(tnf0$syl))

# Melt data frame with a subset of the ID variables
tnf0.molten <- melt(tnf0, id.vars=c("syl", "stress", "status", "sample"), measure.vars=c("f0"))
# Prettier and neater version of head
tbl_df(tnf0.molten)


# How many F0 observations per condition
tnf0.count <- dcast(tnf0.molten,
                    syl + stress + status + sample ~ variable,
                    fun.aggregate = length)
tbl_df(tnf0.count)

# Mean F0 value per sample in 18 conditions (syl + stress + status)
tnf0.cast <- dcast(tnf0.molten,
                   syl + stress + status + sample ~ variable,
                   fun.aggregate = mean)

# Just plot it!
tnf0.cast$status <- factor(tnf0.cast$status, levels = c("new", "given", "control")) 
p <- ggplot(tnf0.cast, aes(x=sample, y=f0, colour=status))
p +
    geom_line() +
    scale_x_continuous("samples (5/syllable)") +
    scale_y_continuous("F0 (Hz)") +
    facet_grid(syl ~ stress) +
    scale_colour_brewer(palette="Set1") +
    theme_bw()
tbl_df(tnf0.cast)