import sys
import smtplib
# Import the email modules we'll need
from email.MIMEMultipart import MIMEMultipart

from email.MIMEText import MIMEText
from email.MIMEBase import MIMEBase
from email import encoders

#here is the class that will deal wtih

#the input and output file

class Home_owner:
    	name = ""
    	no = " "
    	email = "somethingat.com "
    	sensor = " "
    	message =" "



	def loadFromFile(self):
       		f = open("./ahmed.txt", "r")
        	self.name = f.readline().rstrip()
        	self.no =   f.readline().rstrip()
        	self.email = f.readline().rstrip()
        	self.sensor = f.readline().rstrip()
        	self.message= f.readline().rstrip()
#Initiationg a variable
theHome_owner = None

# Giving the method the attributes
theHome_owner = Home_owner()
#Loading information from file
theHome_owner.loadFromFile()



#setting the primary GMAIL email
from_email = "securotech1@gmail.com"

#setting the desttination eamil.
#it doesn't have to be gmail
#dest_email = "ahmedlab7@hotmail.com"
dest_email = theHome_owner.email
#This is the part that deals with the SMS
#via the Carrier Gateway.

dest_email2=theHome_owner.no
#dest_email2=file.readline(2)
message = MIMEMultipart()
message['From'] = from_email
message['To'] = dest_email
message['Subject'] = "Automatic Message Notification "


# Here is where We put the Message
#that the user will get when he opens
#the notification message , whether
#it was Email or SMS; this why it must
#be reasonable in lenght .
body = theHome_owner.message

sensor_type=theHome_owner.sensor
#Later,when we have our camera set, we can
#add this attachment to the message.
message.attach(MIMEText(body, 'plain'))
message.attach(MIMEText(sensor_type, 'plain'))


filename = "Camera Should automatically name this "
#It could be a picutre or a link to the camera
attachment = open("./ahmed.txt", "rb")
# To enable the user to open the attachment
part = MIMEBase('application', 'octet-stream')

part.set_payload((attachment).read())
encoders.encode_base64(part)
part.add_header('Content-Disposition', "attachment; filename= %s" % filename)

message.attach(part)
#Accessing the server from  port:587 or :465
server = smtplib.SMTP('smtp.gmail.com', 587)
server.starttls()
#Login to the server using the password
#of course it's not secure at all
#but it works for now.
#having the username and pass along with phone number is very dangreous
server.login(from_email, "Sust2012")
#Message
text = message.as_string()
server.sendmail(from_email, dest_email,text)
server.sendmail(from_email, dest_email2,text)
server.quit()





























