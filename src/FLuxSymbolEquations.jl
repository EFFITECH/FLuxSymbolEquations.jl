module FLuxSymbolEquations
# excitvar à automatiser OK
# affectation des valeurs pour les composants
# afectation des variables pour plot
# variables d'intégration automatique OK
# just for test
export greet, myStrgToSolve, myGraph
function greet()
	return  "Hello World!"
end
#
mys=""
excitVar=""  # voir 129 et 339
mutable struct Schematics
	Template::Array{String}
end
LLCExample=Schematics(["!VUd 110.,Rp 1e-4 ,Lr 32.4e-6,T1P 1.82e-3,MT1 0.000823308666297155,Cr 39e-9","MT1 ,T1S 380e-6 ,R2 1e-4 ,!rect ,Co 10e-6","Co ,Rl 2.4"])
using SymPy

mutable struct Component

	name::String
	loopNb::Int64
	formula::String
	position::String
	current::String
	special::Bool
	ctype::String
	value::Float64
	rect::Bool
	commons::Int64
	voltage::String
	Component()=new()
end

mutable struct LoopC
	CompInLoop::Array{Component}
	CommonComp::Array{Component}
	LoopNumber::Int64
	LoopC()=new()
end

ComponentTypeSet=Set(["C","R","M","T","m","L"]);

mutable struct CommonComp
	Common::Component
	Loops::Array{Int64}
end

function formul(typ,nam,cur)
	formul=""
	if typ=="R"
		formul="V"*nam*"="*nam*"*"*cur
	elseif typ=="L"
		formul="V"*nam*"="*nam*"*d"*cur
	elseif typ=="C"
		formul=cur*"="*nam*"*dV"*nam
	elseif typ=="T"
		formul="V"*nam*"="*nam*"*d"*cur
	elseif typ=="M"
		formul="V"*nam*"=-"*nam*"*d"*cur
	elseif typ=="m"
		formul="V"*nam*"=-"*"M"*nam[2:end]*"*d"*cur
	end
	return formul
end

# flatten formulas
function flattenEqs()
	flattenEq=""
	# process voltage sum in loop equal zero
	sumvolt=String[]
	for i in 1:length(LLCExample.Template ) push!(sumvolt,"") end
	for i in 1:length(myLoop1)
		sumvolt[myLoop1[i].loopNb]*=myLoop1[i].voltage*"+"
	end
	for j in 1:length(LLCExample.Template)
		sumvolt[j]=sumvolt[j][1:end-1]
	end
	for j in 1:4:length(CommonCmpt)
		if CommonCmpt[j][1:1]!="M"
			sumvolt[CommonCmpt[j+3]]=replace(sumvolt[CommonCmpt[j+3]],"V"*CommonCmpt[j]=>"(-V"*CommonCmpt[j]*")")
		end
	end
	for i in 1:length(sumvolt)
		sumvolt[i]=replace(sumvolt[i],"++"=>"+")
	end
	# delete extra formula
	for i in length(myLoop1):-1:1
		for j in 1:4:length(CommonCmpt)
			if (myLoop1[i].name ==CommonCmpt[j]) && myLoop1[i].current=="I"*string(CommonCmpt[j+3])  && myLoop1[i].ctype!="M"
				splice!(myLoop1, i)
			end
		end
	end

	# build list of equation
	for i in 1:length(myLoop1)
		flattenEq*=replace(myLoop1[i].formula,"="=>"-(")*"),"
	end
	flattenEq=flattenEq[3:end]
	for i in 1:length(sumvolt)
		sumvolt[i]=replace(sumvolt[i],"++"=>"+")
		flattenEq*=sumvolt[i]*","
	end

	flattenEq=replace(flattenEq,",),"=>",")

	return flattenEq[1:end-1],sumvolt
end

function fillCmpt(LLCExample)
	rectOn=false
	myLoop=[]
	CommonCmpt=[]
	CommonLoop=[]
	test=[]
    excitVar0=[]
	for j in 1:length(LLCExample.Template)  # numero de boucle
		parts=split(LLCExample.Template[j],",")
		for i in 1:length(parts)
			tCmpt=Component()
			temp0=split(parts[i]," ")
			if temp0[1][1:1]=="!"
				tCmpt.special=true
				tCmpt.name=temp0[1][2:end]
				if tCmpt.name=="rect"
					rectOn=true
					tCmpt.voltage=""
				else
					tCmpt.voltage=tCmpt.name
					push!(excitVar0,tCmpt.name)
				end

			else
				tCmpt.special=false
				tCmpt.name=temp0[1][1:end]

				if temp0[2]==""  !!!!!!!!!!!!!!!
					tCmpt.commons=j
					push!(CommonCmpt,tCmpt.name)
					push!(CommonLoop,j)
					#tCmpt.value=1e-139 # dummy value
				end


				tCmpt.voltage="V"*tCmpt.name

			end
			tCmpt.ctype=tCmpt.name[1:1]
			tCmpt.loopNb=j
			tCmpt.current="I"*string(tCmpt.loopNb)
			tCmpt.formula=formul(tCmpt.ctype,tCmpt.name,tCmpt.current)
			tCmpt.rect=rectOn
			#if tCmpt.value!=false
			try
				tCmpt.value=parse(Float64, temp0[2])
			catch
				for k in 1:length(myLoop)
					if myLoop[k].name==tCmpt.name
						tCmpt.value=myLoop[k].value
						break
					end
				end
			end
			#end
			push!(myLoop,tCmpt)
		end
	end
	for i in 1:length(myLoop)
		if myLoop[i].name in CommonCmpt
			push!(test,myLoop[i].name)
			push!(test,myLoop[i].loopNb)
		end
	end
	return myLoop,test,excitVar0
end
myLoop,CommonCmpt,excitVar=fillCmpt(LLCExample)
	# process transformer and common
function proct()
	cur=[]
	for i in 1:length(myLoop)
		if myLoop[i].ctype=="M"
			push!(cur,myLoop[i].current)
		end
	end
	fstok=0
	for i in 1:length(myLoop)
		if myLoop[i].ctype=="M"	&& fstok==0
			myLoop[i].current=pop!(cur)
			#myLoop[i].formula=myLoop[i].formula[1:end-2]*myLoop[i].current
			myLoop[i].formula=myLoop[i].formula[1:4]*"P"*myLoop[i].formula[5:end-2]*myLoop[i].current

			myLoop[i].voltage=myLoop[i].voltage*"P"
			fstok=1
		elseif myLoop[i].ctype=="M"	&& fstok==1
			myLoop[i].current=pop!(cur)
			#myLoop[i].formula=myLoop[i].formula[1:end-2]*myLoop[i].current
			myLoop[i].formula=myLoop[i].formula[1:4]*"S"*myLoop[i].formula[5:end-2]*myLoop[i].current
			myLoop[i].voltage=myLoop[i].voltage*"S"
			fstok=0
		end
	end

	for i in 1:2:length(CommonCmpt)   # courants impliqués  cur= [2, 3]
		if CommonCmpt[i][1:1]!="M"
			push!(cur,CommonCmpt[i+1])
		end
	end
	for i in 1:4:length(CommonCmpt)
		if CommonCmpt[i][1:1]!="M"
			for j in 1:length(myLoop)    # process for common componzents
				if myLoop[j].name==CommonCmpt[i]   #replace I2  with (I2-I3)
					myLoop[j].formula=replace(myLoop[j].formula,"I"*string(cur[1])=>"(I"*string(cur[1])*"-I"*string(cur[2])*")")
				end
			end
		end
	end
	return  myLoop
end



myLoop1=proct()
flattenEqs1,sumvolt=flattenEqs()



#dVCr,dI1,VLr,VT1P,VMT1,VRp,dVCo,dI2,VmT1,VT1S,VR2,VRl,I3
function getmyVars()
	mySymbvars=[]  # all symbolic var
	myvars=[]   # var to be integrated by ODE
	myvars1=""
	for i in 1:length(myLoop1)
		if myLoop1[i].ctype in ["L","M","T"]
			push!(myvars,"d"*myLoop1[i].current)
			push!(mySymbvars,myLoop1[i].current)
		elseif myLoop1[i].ctype=="C"
			push!(myvars,"d"*myLoop1[i].voltage)
			push!(mySymbvars,myLoop1[i].voltage)

		end
	end
	for i in 1:length(myLoop1)
		if myLoop1[i].name !="" && myLoop1[i].name !="rect"
		#push!(myvars, myLoop1[i].current)
			if myLoop1[i].special==false && ("d"*myLoop1[i].voltage in myvars) == false
				push!(myvars,myLoop1[i].voltage)
			else
				push!(mySymbvars,myLoop1[i].voltage)
			end
		push!(mySymbvars,myLoop1[i].name)
		end
	end
	myvars=unique(myvars)
    mySymbvars=unique(mySymbvars)
	#il faut rajouter I3 car pas dI3
	for i in 1:length(LLCExample.Template)
		if ("dI"*string(i) in myvars) == false
			push!(myvars,"I"*string(i))
		end
	end
	return myvars,mySymbvars
end
myLoop[7].value

#process CommonCmpt ["MT1", 1, MT2, 2, ...]






myVar=getmyVars()

#Création des noms symboliques)
for j in 1:length(myVar)
	for i in 1:length(myVar[j])
		try
			symbdat=replace(replace(replace(string(myVar[i]),"\"" =>""),"Any["=>""),"]"=>"")
			eval(Meta.parse(symbdat*"=symbols(\""*symbdat*"\")"))
		catch
		end
	end
end

function flatVars()
	myvars1=""
   for i in 1:length(myVar[1])
		myvars1*=myVar[1][i]*","
	end
	return myvars1[1:end-1]
end

flatVars()



# create rectComp="I2,Co,Rl"
function rectdata()
	rectComp=""
	for i in 1:length(myLoop1)
		if myLoop1[i].name=="rect"
			rectComp*=myLoop1[i].current*","
		elseif myLoop1[i].rect==true
			rectComp*=myLoop1[i].name*","
		end
	end
		return rectComp[1:end-1]
end

rectComp=rectdata()

compsRect=split(rectComp,",")

if compsRect!=[] cour=compsRect[1] end



Az=linsolve(eval(Meta.parse(flattenEqs1)),eval(Meta.parse(flatVars())))

string.(Az)

mysol=split(replace(string.(Az),"FiniteSet(("=>"")[1:end-2],",")
VartoSolve=myVar[1]
mydVoudIindx=findall.("d",VartoSolve)
difEqIndex=findall(mydVoudIindx -> mydVoudIindx!=[],mydVoudIindx)
mydifEq=VartoSolve[difEqIndex].*"=".*mysol[difEqIndex]

mydifEq

function rect()
	compsRect=split(rectComp,",")
	cour=""
	if compsRect!=[] cour=compsRect[1] end
	my=[]
	for i in 1:length(compsRect)
		if compsRect[i][1:1]=="C"
			for j in 1:length(mydifEq)
				if mydifEq[j][1:2+length(compsRect[i])]=="dV"*compsRect[i]
					push!(my,replace(mydifEq[j],cour=>"abs("*cour*")"))
				else #Uco*(-sign(Is))
					push!(my,replace(mydifEq[j],"V"*compsRect[i]=>"V"*compsRect[i]*"*(sign("*cour*"))"))
				end
			end
		end
	end

	return my
end

rect()
myst=""

function collectVar(rt)
	myst=""
	myVrArray=[]
	for i in 1:length(rt)
	myst=myst*rt[i][2:findfirst(isequal('='), rt[i])-1]*","
	push!(myVrArray,rt[i][2:findfirst(isequal('='), rt[i])-1])
	end
	return myst[1:end-1],myVrArray
end
myst,myVrArray=collectVar(rect())

myStrgToSolve=""
myStrgToSolve1=""
rect1=[]
for i in 1:length(rect())
	push!(rect1,"du["*string(i)*"] = "*rect()[i])
end
rect1


function flatEqs(sympyEq)
	eqstoSolv=""
	myflatVar=""
	for ii in 1:length(sympyEq)-1
		eqstoSolv=eqstoSolv*sympyEq[ii]*","
	end
	eqstoSolv=eqstoSolv*sympyEq[length(sympyEq)]
	for ii in 1:length(myVar)-1
		myflatVar=myflatVar*myVar[1][ii]*","
	end
	myflatVar=myflatVar*myVar[1][length(myVar)]
	return eqstoSolv,myflatVar
end
rect1
excitVar=fillCmpt(LLCExample)[3]
#replace.(rect1,excitVar=>excitVar*"*p[1]")
myStrgToSolve=flatEqs(replace.(rect1,excitVar[1]=>excitVar[1]*"*p[1]"))[1]*"; end"


#"VRp-(Rp*I1),VLr-(Lr*dI1),VT1P-(T1P*dI1),VMT1-(-MT1*dI2),VmT1-(-MT1*dI1),VT1S-(T1S*dI2),VR2-(R2*I2),VRl-(Rl*I3),VUd+VRp+VLr+VT1P+VMT1+VCr,VmT1+VT1S+VR2+VCo,(-VCo)+VRl,I1-(Cr*dVCr),I2-I3-(Co*dVCo)"


 #  "source": [
#    "du[1]=dIp=(-Ip*Ls*Rp - Is*M*R - Ls*Ucr + Ls*Ud*p[1] + M*Uco*(-sign(Is)))/(Lp*Ls + Lr*Ls - M^2);\n",
#    "#du[2]=dI1= -(I1*Rp*T1S + I2*MT1*R2 + MT1*VCo*(-sign(I2)) + T1S*VCr + T1S*VUd*p[1])/(Lr*T1S - MT1^2 + T1P*T1S);\n",
#    "\n",
#    "du[2]=dIs=(-Ip*M*Rp - Is*R*(Lp + Lr) - M*Ucr + M*Ud*p[1] + Uco*(-sign(Is))*(Lp + Lr))/(Lp*Ls + Lr*Ls - M^2);\n",
#    "du[3]=dUcr=Ip/Cr;\n",
#    "#du[1]=dVCr=I1/Cr;\n",
#    "\n",
#    "du[4]=dUco=(abs(Is)*R - Uco)/(Co*R);end\n",
#    "#du[3]=dVCo= (abs(I2)*Rl + VCo)/(Co*Rl); \n",
#    "\n",
#    "du[2]=dIs=(-Ip*M*Rp - Is*R*(Lp + Lr) - M*Ucr + M*Ud*p[1] + Uco*(-sign(Is))*(Lp + Lr))/(Lp*Ls + Lr*Ls - M^2);\n",
#    "#du[4]=dI2= -(I1*MT1*Rp + I2*Lr*R2 + I2*R2*T1P + Lr*VCo*(-sign(I2)) + MT1*VCr + MT1*VUd*p[1] + T1P*VCo*(-sign(I2)))/(Lr*T1S - MT1^2 + T1P*T1S);"
 #  ]


# A Valider
excitVar
myStrgToSolve1="function eqDiffToSolve!(du,u,p,t) "* myst *" = u; " *replace(myStrgToSolve,","=>"; ") #!!!!!!


eval(Meta.parse(myStrgToSolve1))


#function solveConvert()
#Ud=110.;Rp=0.1e-3;Lp=1.82e-3;Lr=32.4e-6;k=0.99;Ls=380.e-6;M=k*(Lp*Ls)^.5;Cr=39e-9;Co=10e-6;R=2.4;freq=1e5
freq=1e5  #OK
#VUd=110.;  #OK
#Rp =1e-4 ; #OK
#Lr= 32.4e-6; #OK
#T1P= 1.82e-3 ; #OK
#MT1 =0.000823308666297155; #OK
#Cr= 39e-9; #OK
#T1S =380e-6 ;
#R2= 1e-4;
#Co=10e-6;
#Rl= 2.4
u₀=[0,0,0,0]
p=[-1.0,1.0]
tspan = (0.0,600.e-6)
nbPeriod=60
dosetimes = collect(1:nbPeriod)/freq/2
eval(Meta.parse(myStrgToSolve1))

for i in 1:length(myLoop)
	#if typeof(myLoop[i].value)!=1e-139
		try eval(Meta.parse(myLoop[i].name*"="*string(myLoop[i].value)))
		catch
		end
	#end
end


using DifferentialEquations
prob = ODEProblem(eqDiffToSolve! ,u₀,tspan,p)
condition(u,t,integrator) = t ∈ dosetimes
affect!(integrator) = integrator.p[1] = -integrator.p[1]
cb = DiscreteCallback(condition,affect!)

sol= DifferentialEquations.solve(prob ,Tsit5(),callback=cb,tstops=dosetimes)
using Plots
myGraph=plot(sol,linewidth=2,xaxis="t",label=permutedims(myVrArray),layout=(4,1))


end
