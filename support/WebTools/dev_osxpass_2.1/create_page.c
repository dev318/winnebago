#include <stdio.h>


//-------------------------------------------------------------------------------------
//	create_page
//-------------------------------------------------------------------------------------

void create_page(char *message)
{


		printf("%s", "<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN'>\n");
		
		printf("%s", "<html>\n");
		
		printf("%s", "<head>\n");
		printf("%s", "		<meta http-equiv='content-type' content='text/html;charset=ISO-8859-1'>\n");
		
		printf("%s", "		<title>Migrate Your Password</title>\n");
		printf("%s", "	</head>\n");
		
		printf("%s", "	<BODY BGCOLOR=#FFFFFF LEFTMARGIN=0 TOPMARGIN=0 MARGINWIDTH=0 MARGINHEIGHT=0 background='/images/bg1.gif'>\n");
		
		printf("%s", "		<table width='600' border='0' cellspacing='0' cellpadding='0' align='center'>\n");
		printf("%s", "			<tr>\n");
		printf("%s", "				<td>\n");
		printf("%s", "					<table width='600' border='0' cellspacing='0' cellpadding='0' bgcolor='white'>\n");
		printf("%s", "						<tr>\n");
		printf("%s", "							<td align='left' valign='middle' background='/images/astripe.gif'>\n");
		printf("%s", "								<table width='100%' border='0' cellspacing='0' cellpadding='0'>\n");
		printf("%s", "									<tr>\n");
		printf("%s", "										<td background='/images/astripe2.gif'>\n");
		printf("%s", "											<div align='center'>\n");
		printf("%s", "												<img src='/images/header.jpg' alt='' height='100' width='600' border='0'></div>\n");
		printf("%s", "										</td>\n");
		printf("%s", "									</tr>\n");
		printf("%s", "								</table>\n");
		printf("%s", "							</td>\n");
		printf("%s", "						</tr>\n");
		printf("%s", "						<tr height='2'>\n");
		printf("%s", "							<td height='2' background='/images/hstrip.gif'><img src='/images/hstrip.gif' alt='' height='2' width='100%' border='0'></td>\n");
		printf("%s", "						</tr>\n");
		printf("%s", "						<tr>\n");
		printf("%s", "							<td background='/images/astripe.gif'>\n");
		printf("%s", "								<p></p>\n");
		printf("%s", "								<div align='center'>\n");
				
		printf("%s", "									<table width='450' border='2' cellspacing='2' cellpadding='15' background='/images/astripe2.gif'>\n");
		
		if (message != NULL && strcmp(message,"")) {
			printf("%s", "										<tr>\n");
			printf("%s%s%s", "											<td align='left'><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><b><i>", message, "</i></b></font></td>\n");
			printf("%s", "										</tr>\n");
		}	
		
		printf("%s", "										<tr>\n");
	printf("%s", "											<td align='left'><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'>Enter  your current Network Username & Password and click the Migrate Password button. Once the process is successful, you can close this page. If you're using a Mac please run the <a href=\"/MacMigrator.app.zip\">Mac Migration</a></font></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td align='center'>\n");
		printf("%s", "												<form action='index.cgi' method='post' name='changepassword'>\n");
                printf("%s", "												<input type='hidden' name='action' value='xpass'>\n");
		printf("%s", "																					<table width='239' border='0' cellspacing='2' cellpadding='0'>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td align='right'><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><b>Username</b></font></td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td><input type='text' name='uname' size='24' border='0'></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td align='right'>&nbsp;</td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td>&nbsp;</td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "														<tr>\n");
		printf("%s", "															<td align='right'><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><b>Password</b></font></td>\n");
		printf("%s", "															<td width='10'>&nbsp;</td>\n");
		printf("%s", "															<td><input type='password' name='old_pw' size='24' border='0'></td>\n");
		printf("%s", "														</tr>\n");
		printf("%s", "														<tr>\n");
		printf("%s", "															<td align='right'>&nbsp;</td>\n");
		printf("%s", "															<td width='10'>&nbsp;</td>\n");
		printf("%s", "															<td>&nbsp;</td>\n");
		printf("%s", "														</tr>\n");
		printf("%s", "														<tr>\n");
		printf("%s", "											<td align='right'><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><b>Verify</b></font></td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td><input type='password' name='new_pw1' size='24' border='0'></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td align='right'>&nbsp;</td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td>&nbsp;</td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		//printf("%s", "											<td align='right'><b><font size='2' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'>Verify</font></b></td>\n");
		//printf("%s", "											<td width='10'>&nbsp;</td>\n");
		//printf("%s", "											<td><input type='password' name='new_pw2' size='24' border='0'></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td>&nbsp;</td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td>&nbsp;</td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td>&nbsp;</td>\n");
		printf("%s", "											<td width='10'>&nbsp;</td>\n");
		printf("%s", "											<td><input type='submit' name='submitButtonName' value='Migrate Password' border='0'></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "									</table>\n");
		printf("%s", "												</form>\n");
		
		printf("%s", "											</td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "										<tr>\n");
		printf("%s", "											<td align='left'><font size='1' color='#cc0000' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><i>Attention!</i></font><font size='1' face='Arial,Helvetica,Geneva,Swiss,SunSans-Regular'><i> This web application is intended for use by authorized users. Use by others is prohibited. Anyone found attempting to abuse this application will be prosecuted.</i><br>\n");
		printf("%s", "												</font></td>\n");
		printf("%s", "										</tr>\n");
		printf("%s", "									</table>\n");
		printf("%s", "								</div>\n");
		printf("%s", "								<p></p>\n");
		printf("%s", "								<p><br>\n");
		printf("%s", "								</p>\n");
		printf("%s", "							</td>\n");
		printf("%s", "						</tr>\n");
		printf("%s", "						<tr>\n");
		printf("%s", "							<td align='center' valign='top' background='/images/astripe.gif'><a href='http://www.318.com' target='_blank'><img src='/images/eb_footer.gif' alt='' height='108' width='600' border='0'></a></td>\n");
		printf("%s", "						</tr>\n");
		printf("%s", "					</table>\n");
		printf("%s", "				</td>\n");
		printf("%s", "			</tr>\n");
		printf("%s", "		</table>\n");
		printf("%s", "		<p></p>\n");
		printf("%s", "	</body>\n");
		
		printf("%s", "</html>\n");
}