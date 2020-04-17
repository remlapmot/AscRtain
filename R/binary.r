#' V-structure bias, binary exposure and binary outcome.
#'
#' Explore bias due to sample ascertainment when the exposure and outcome are binary variables. This class explores the range or OR generated by parameters in the following model:
#' P(S = 1 | A,Y) = b0 + ba*A + by*Y + bay*AY
#' Where A is a binary exposure, Y is a binary outcome and S indicates whether an individual is present in the dataset
#' P(S = 1) is the proportion of the population that is present in the data.
#'
#' @importFrom R6 R6Class
#' @export
VBB <- R6Class("VBB", list(

	#' @field param Dataframe of parameter range list
	param = NULL,

	#' @description
	#' Calculate the expected OR under collider bias when null hypothoses of OR = 1 is true:
	#' @param b0 Baseline probability of being selected
	#' @param ba Effect of A on being selected
	#' @param by Effect of Y on being selected
	#' @param bay Effect of joint AY interaction on being selected
	#'
	#' @return Odds ratio
	or_calc = function(b0, ba, by, bay)
	{
		b0 * (b0 + ba + by + bay) / ((b0 + ba) * (b0 + by))
	},
	
	#' @description
	#' Calculate the proportion of samples included in the model for a given set of parameters
	#' @param b0 Baseline probability of being selected
	#' @param ba Effect of A on being selected
	#' @param by Effect of Y on being selected
	#' @param bay Effect of joint AY interaction on being selected
	#' @param pA P(A = 1) in the general population
	#' @param pY P(Y = 1) in the general population
	#' @param pAY P(A = 1, Y = 1) in the general population
	#'
	#' @return P(S = 1)
	ps_calc = function(b0, ba, by, bay, pA, pY, pAY)
	{
		b0 + ba * pA + by * pY + bay * pAY
	},

	#' @description
	#' Specify a set of parameters for the structural equation, and calculate the set of odds ratios that would be obtained, assuming the odds ratio of A on Y in the total population is 1.
	#' @param target_or Target odds ratio. e.g. in an observational study this OR is observed, and the researcher seeks to find parameter ranges that could explain it
	#' @param pS Proportion of the population present in the sample
	#' @param pA P(A = 1) in the general population
	#' @param pY P(Y = 1) in the general population
	#' @param pAY P(A = 1, Y = 1) in the general population
	#' @param b0_range Baseline probability of being selected. Provide a range of values to explore e.g. c(0,1)
	#' @param ba_range Effect of A on being selected into the sample. Provide a range of values to explore e.g. c(-0.2, 0.2)
	#' @param by_range Effect of Y on being selected into the sample. Provide a range of values to explore e.g. c(-0.2, 0.2)
	#' @param bay_range Effect of AY interaction on being selected into the sample. Provide a range of values to explore e.g. c(-0.2, 0.2)
	#' @param granularity Granularity of the search space. Default=100, going much higher can be computationally difficult
	#' @param pS_tol Tolerance of pS value Default=0.0025
	#' @return Data frame of parameters that satisfy the target_or and target pS values
	parameter_space = function(target_or, pS, pA, pY, pAY, b0_range, ba_range, by_range, bay_range, granularity=100, pS_tol=0.0025)
	{
		s <- sign(log(target_or))
		param <- expand.grid(
			pA = pA,
			pY = pY,
			pAY = pAY,
			b0 = seq(b0_range[1], b0_range[2], length.out=granularity) %>% unique(),
			ba = seq(ba_range[1], ba_range[2], length.out=granularity) %>% unique(),
			by = seq(by_range[1], by_range[2], length.out=granularity) %>% unique(),
			bay = seq(bay_range[1], bay_range[2], length.out=granularity) %>% unique()
		)
		message(nrow(param), " parameter combinations")
		param <- param %>%
		dplyr::mutate(ps1 = self$ps_calc(b0=b0, ba=ba, pA=pA, by=by, pY=pY, bay=bay, pAY=pAY)) %>%
		dplyr::filter(ps1 >= pS - pS_tol & ps1 <= pS + pS_tol & b0 + by + ba + bay > 0) %>%
		dplyr::mutate(or = self$or_calc(b0=b0, ba=ba, by=by, bay=bay))
		message(nrow(param), " within pS_tol")
		if(target_or >= 1)
		{
			param <- subset(param, or >= target_or & or < 50)
		} else {
			param <- subset(param, or <= target_or & or > 0)
		}
		message(nrow(param), " beyond OR threshold")
		self$param <- dplyr::as_tibble(param)
	},

	#' @description
	#' 3D scatterplot of output from parameter_space function. See plot3D::scatter3D for info on parameters
	#' @param ticktype Default="detailed"
	#' @param theta Default=130
	#' @param phi Default=0
	#' @param bty Default="g"
	#' @param xlab Default="ba"
	#' @param ylab Default="by"
	#' @param zlab Default="b0"
	#' @param clab Default="OR"
	#' @param ... Further parameters to be passed to plot3D::scatter3D
	#' @return Scatterplot
	scatter3d = function(ticktype="detailed", theta=130, phi=0, bty="g", xlab="ba", ylab="by", zlab="b0", clab="OR", ...)
	{
		plot3D::scatter3D(self$param$ba, self$param$by, self$param$b0, colvar=self$param$or, ticktype = ticktype, theta=theta, phi=phi, bty=bty, xlab=xlab, ylab=ylab, zlab=zlab, clab=clab, ...)
	},

	#' @description
	#' Simple scatterplot of output from parameter_space function. Plotted are the parameter values of b0, ba and by that can give rise to an OR >= target_or
	scatter = function()
	{
		ggplot2::ggplot(self$param, ggplot2::aes(x=ba, y=by)) +
		ggplot2::geom_point(ggplot2::aes(colour=b0))
	},

	#' @description
	#' Histogram of odds ratios across the range of parameter values
	#' @param bins How many bins to split histogram. Default=30
	#'
	#' @return ggplot object
	histogram = function(bins=30)
	{
		ggplot2::ggplot(self$param, ggplot2::aes(x=or)) +
		ggplot2::geom_histogram(bins=bins) +
		ggplot2::scale_x_log10()
	}

))
