# averager.R - Program to average out all 10 minutes data and produce a hourly based AQG

# Auxiliary function: computes wind vector hourly average from 10 minutes samples
wind.avg <- function(vel, dir) {
  
  # Change single vel-dir couples to wind vectors
  u <- vel * sin(dir*pi/180);
  v <- vel * cos(dir*pi/180);
  
  # Compute componentwise average and transform it to vel-dir couple
  u.avg <- mean(u, na.rm=T);
  v.avg <- mean(v, na.rm=T);
  vel.avg <- sqrt(u.avg^2 + v.avg^2);
  dir.avg <- 180/pi * atan2(u.avg,v.avg);
  dir.avg[dir.avg<0] <- dir.avg[dir.avg<0] + 360;
  
  return(list(vel=vel.avg,dir=dir.avg));
  
}


# Golder (1972) stability category estimation from similarity data,
# as from LSTAB function in CTDM+, and equivalent routines in MESOPUFF II,
# Calpuff, ...
# (This routine is not in original PBL_MET).
#
lstab <- function(L,z0) {
  
  # Line separating the z0-L graph in Golder paper, as approximated in CTDM+
  XL <- function(Y,XM,B) {
    return(XM/(log(Y)-B));
  }
  
  # Ensure z0 to be within common range
  z0 <- min(c(z0,0.5));
  z0 <- max(c(z0,0.01));
  
  # Build separation lines
  unstable.set <- c(
    XL(z0,-70.0,4.35),
    XL(z0,-85.2,0.502),
    XL(z0,-245.,0.050)
  );
  stable.set <- c(
    XL(z0,-70.0,0.295),
    XL(z0,-327.,0.627)
  );
  
  # Classify stability depending on L
  istab <- integer(length(L));
  unstable.data <- which(L < 0);
  stable.data   <- which(L >= 0);
  unstable.L    <- L[unstable.data];
  stable.L      <- L[stable.data];
  istab.unstable <- approxfun(x=unstable.set, y=c(1,2,3), yleft=1, yright=4, method="constant");
  istab.stable   <- approxfun(x=stable.set,   y=c(5,4),   yleft=6, yright=4, method="constant");
  istab[unstable.data] <- istab.unstable(unstable.L);
  istab[stable.data]   <- istab.stable(stable.L);
  
  # Yield result and return
  return(istab);
  
}



# Get the two data frames and join them by time stamp
sonic <- read.csv("/mnt/ramdisk/Data_SN.csv");
n <- length(sonic$Date.Time)
sonic$Date.Time <- as.POSIXct(as.character(sonic$Date.Time), tz="UTC");
meteo <- data.frame(
	Time.Stamp=sonic$Date.Time,
	Temp.Mean=rep(-9999.9,times=n),
	Urel.Mean=rep(-9999.9,times=n), 
	Rg.Mean  =rep(-9999.9,times=n), 
	Rn.Mean  =rep(-9999.9,times=n), 
	RIr.Mean =rep(-9999.9,times=n), 
	TRIr.Mean=rep(-9999.9,times=n), 
	Rain.Sum =rep(-9999.9,times=n)
);
d <- merge(sonic, meteo, by.x="Date.Time", by.y="Time.Stamp");

# Limit attention to well-formed dates and times
limit.date <- as.POSIXct("2000-01-01 00:00:00", tz="UTC");
d <- d[which(d$Date.Time >= limit.date),];

# Compute hourly averages
DATA  <- substring(strftime(d$Date.Time, format="%d/%m/%Y", tz="UTC"), first=1, last=10);
ORA   <- substring(as.character(d$Date.Time), first=12, last=13);
Temp  <- mean(d$Temp.Mean, na.rm=TRUE);
Urel  <- mean(d$Urel.Mean, na.rm=TRUE);
RG    <- mean(d$Rg.Mean, na.rm=TRUE);
RN    <- mean(d$Rn.Mean, na.rm=TRUE);
RIr   <- mean(d$RIr.Mean, na.rm=TRUE);
TRIr  <- mean(d$TRIr.Mean, na.rm=TRUE);
Rain_Sum <- sum(d$Rain.Sum, na.rm=TRUE);
vect  <- wind.avg(d$Vel, d$Dir);
VS    <- vect$vel;
DS    <- vect$dir;
TS    <- mean(d$Temp, na.rm=TRUE);
us    <- mean(d$U.star, na.rm=TRUE);
zL    <- mean(d$z.L, na.rm=TRUE);
H0    <- mean(d$H0, na.rm=TRUE);
THK   <- mean(d$TKE, na.rm=TRUE);
Istab <- lstab(10/zL, 0.023);
SU    <- mean(d$Sigma.U, na.rm=TRUE);
SV    <- mean(d$Sigma.V, na.rm=TRUE);
SW    <- mean(d$Sigma.W, na.rm=TRUE);
ST    <- mean(d$Sigma.T, na.rm=TRUE);
tstar <- mean(d$T.star, na.rm=TRUE);
e <- data.frame(DATA=DATA[1], ORA=ORA[1], Temp, Urel, RG, RN, RIr, TRIr, Rain_Sum, VS, DS, TS, us, zL, H0, THK, SU, SV, SW, ST, tstar, Istab);
if(length(levels(e$DATA)) >= 0) {

	valid.rows <- !is.na(e$DATA);
	e<-e[valid.rows,];
	
	# Transform any "NA" to -9999.9
	e[is.na(e)] <- -9999.9;

	# Write data in AQG form
	if(length(e$DATA) > 0) {

		write.csv(e, file="/mnt/ramdisk/hourlyData.aqg", row.names=FALSE);
		txt <- "DATA\tORA\tTemp\tUrel\tRG\tRN\tRIr\tTRIr\tRain_Sum\tVS\tDS\tTS\tU*\tzL\tH0\tTHK\tSU\tSV\tSW\tST\tT*\tIstab"
		for(i in 1:length(e$DATA)) {
			s <- sprintf("%s\t%s\t%7.1f\t%7.1f\t%7.1f\t%7.1f\t%7.1f\t%7.1f\t%7.1f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%9.3f\t%2d",e$DATA[i],e$ORA[i],round(e$Temp[i],1),round(e$Urel[i],1),round(e$RG[i],1),round(e$RN[i],1),round(e$RIr[i],1),round(e$TRIr[i],1),round(e$Rain_Sum[i],1),round(e$VS[i],3),round(e$DS[i],3),round(e$TS[i],3),round(e$us[i],3),round(e$zL[i],3),round(e$H0[i],3),round(e$THK[i],3),round(e$SU[i],3),round(e$SV[i],3),round(e$SW[i],3),round(e$ST[i],3),round(e$tstar[i],3),e$Istab[i])
			txt <- c(txt,s)
		}
		writeLines(txt, "/mnt/ramdisk/hourlyData.aqg")
	}
}


#str(e);

